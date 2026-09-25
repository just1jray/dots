#!/usr/bin/env bash
# Fake tools are written as single-quoted bash lines on purpose.
# shellcheck disable=SC2016

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ORIGINAL_PATH=$PATH
JQ_BIN=$(command -v jq)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

pass_count=0
failure_count=0

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected=$1
    local actual=$2
    local message=$3
    [ "$expected" = "$actual" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
    local needle=$1
    local file=$2
    local message=$3
    grep -F "$needle" "$file" >/dev/null || fail "$message (missing '$needle')"
}

assert_not_contains() {
    local needle=$1
    local file=$2
    local message=$3
    if grep -F "$needle" "$file" >/dev/null; then
        fail "$message (unexpected '$needle')"
    fi
}

write_fake() {
    local name=$1
    shift
    printf '%s\n' '#!/usr/bin/env bash' "$@" >"$FAKE_BIN/$name"
    chmod +x "$FAKE_BIN/$name"
}

new_case() {
    local name=$1
    CASE_ROOT="$TEST_ROOT/$name"
    HOME="$CASE_ROOT/home"
    FAKE_BIN="$CASE_ROOT/bin"
    OUTPUT="$CASE_ROOT/output"
    TOOL_LOG="$CASE_ROOT/tools.log"
    mkdir -p "$HOME" "$FAKE_BIN"
    : >"$TOOL_LOG"
    export HOME TOOL_LOG
    PATH="$FAKE_BIN:$ORIGINAL_PATH"
    export PATH

    write_fake uname 'printf "%s\n" Linux'
    write_fake id 'printf "%s\n" 0'
    write_fake sudo 'printf "sudo %s\n" "$*" >>"$TOOL_LOG"' 'exit 99'
    write_fake apt-cache 'printf "apt-cache %s\n" "$*" >>"$TOOL_LOG"' 'exit 0'
    write_fake apt-get \
        'printf "apt-get %s\n" "$*" >>"$TOOL_LOG"' \
        'exit 0'
    write_fake curl ': >"$2"'
    write_fake unzip \
        'while [ "$1" != "-d" ]; do shift; done' \
        'shift' \
        'touch "$1/JetBrainsMonoNerdFontMono-Regular.ttf"' \
        'touch "$1/JetBrainsMonoNerdFontMono-Bold.ttf"'

    local command_name
    for command_name in git zsh vim tmux fc-cache brew; do
        write_fake "$command_name" 'exit 0'
    done
    write_fake nvim \
        'if [ "${1:-}" = "--version" ]; then printf "%s\n" "NVIM v0.test"; fi' \
        'exit 0'
}

run_setup() {
    set +e
    (
        cd "$REPO_ROOT"
        ./setup.sh "$@"
    ) >"$OUTPUT" 2>&1
    SETUP_STATUS=$?
    set -e
}

test_font_counter_survives_set_e() {
    new_case font-counter

    run_setup --profile full --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "copying the first font must not abort setup"
    assert_contains "Installed 2 JetBrains Mono Nerd Font files" "$OUTPUT" \
        "all extracted fonts should be counted"
}

test_root_apt_does_not_use_sudo() {
    new_case root-apt

    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "successful root apt install should complete setup"
    assert_not_contains "sudo " "$TOOL_LOG" "root apt path must bypass sudo"
    assert_contains "apt-get install -y zsh" "$TOOL_LOG" "zsh should be installed"
    assert_contains "apt-get install -y git" "$TOOL_LOG" "git should be installed"
    assert_contains "apt-get install -y starship" "$TOOL_LOG" "starship should be installed"
}

test_partial_apt_failure_returns_nonzero() {
    new_case partial-apt
    write_fake apt-get \
        'printf "apt-get %s\n" "$*" >>"$TOOL_LOG"' \
        'case " $* " in' \
        '  *" install -y starship "*) exit 1 ;;' \
        'esac' \
        'exit 0'

    run_setup --profile minimal --skip-plugins

    assert_eq "1" "$SETUP_STATUS" "required package failure should produce final nonzero status"
    assert_contains "apt-get install -y zsh" "$TOOL_LOG" \
        "packages before the failure should still install"
    assert_contains "apt-get install -y git" "$TOOL_LOG" \
        "independent packages should still install"
    assert_contains "apt-get install -y starship" "$TOOL_LOG" \
        "the failed package should be attempted"
    assert_contains "Required package installation failed" "$OUTPUT" \
        "final failure summary should be explicit"
    assert_not_contains "Setup completed successfully!" "$OUTPUT" \
        "setup must not print unconditional success"
}

test_starship_missing_from_apt_uses_official_installer() {
    new_case starship-fallback
    write_fake apt-cache \
        'printf "apt-cache %s\n" "$*" >>"$TOOL_LOG"' \
        'case " $* " in *" starship "*) exit 100 ;; esac' \
        'exit 0'
    write_fake curl 'printf "curl %s\n" "$*" >>"$TOOL_LOG"' ': >"$2"'

    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "a package apt lacks must not fail setup when its installer succeeds"
    assert_not_contains "apt-get install -y starship" "$TOOL_LOG" \
        "apt must not be asked for a package it lacks"
    assert_contains "curl -fsSLo" "$TOOL_LOG" "the official installer should be downloaded"
    assert_contains "Installed starship into $HOME/.local/bin" "$OUTPUT" \
        "fallback success should be reported"
    assert_contains "Setup completed successfully!" "$OUTPUT" "setup should end in success"
}

test_starship_installer_failure_is_reported() {
    new_case starship-fallback-fails
    write_fake apt-cache 'case " $* " in *" starship "*) exit 100 ;; esac' 'exit 0'
    write_fake curl 'printf "exit 1\n" >"$2"'

    run_setup --profile minimal --skip-plugins

    assert_eq "1" "$SETUP_STATUS" "a failed fallback installer is a required-package failure"
    assert_contains "The starship installer failed." "$OUTPUT" "installer failure should be reported"
    assert_contains "Required package installation failed" "$OUTPUT" \
        "final summary should be explicit"
}

test_darwin_brew_install_failure_returns_nonzero() {
    new_case darwin-brew-fails
    write_fake uname 'printf "%s\n" Darwin'
    write_fake brew 'printf "brew %s\n" "$*" >>"$TOOL_LOG"' 'exit 1'

    run_setup --profile minimal --skip-plugins

    assert_eq "1" "$SETUP_STATUS" "a failed brew install is a required-package failure, like apt"
    assert_contains "brew install zsh git starship" "$TOOL_LOG" \
        "brew should be asked for the profile packages"
    assert_contains "Required package installation failed" "$OUTPUT" \
        "final summary should be explicit"
    assert_not_contains "Setup completed successfully!" "$OUTPUT" "setup must not print success"
}

test_tpm_installs_after_tmux_conf_is_linked() {
    new_case tpm-order
    cat >"$CASE_ROOT/fake-install-plugins" <<'EOF'
#!/usr/bin/env bash
if [ ! -L "$HOME/.tmux.conf" ]; then
    echo "FATAL: Tmux Plugin Manager not configured in tmux.conf"
    exit 1
fi
printf 'tpm install_plugins\n' >>"$TOOL_LOG"
EOF
    write_fake git \
        'if [ "$1" = clone ]; then' \
        '    mkdir -p "${@: -1}/bin"' \
        "    cp \"$CASE_ROOT/fake-install-plugins\" \"\${@: -1}/bin/install_plugins\"" \
        '    chmod +x "${@: -1}/bin/install_plugins"' \
        'fi' \
        'exit 0'

    run_setup --profile full

    assert_eq "0" "$SETUP_STATUS" "full setup should succeed"
    assert_contains "Tmux plugins installed successfully" "$OUTPUT" \
        "TPM must run after ~/.tmux.conf is linked"
    assert_contains "tpm install_plugins" "$TOOL_LOG" "the TPM installer should have run"
    assert_not_contains "FATAL: Tmux Plugin Manager not configured" "$OUTPUT" \
        "TPM must not see a missing tmux.conf"
}

test_ai_profile_installs_claude_and_cursor_config() {
    new_case ai-profile

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "AI profile should install non-interactively"
    assert_contains "Active profiles: ai" "$OUTPUT" "AI should be the canonical profile name"
    [ -L "$HOME/.claude/CLAUDE.md" ] || fail "AI profile should install Claude config"
    [ -f "$HOME/.cursor/cli-config.json" ] || fail "AI profile should install Cursor preferences"
}

test_claude_profile_is_rejected() {
    new_case rejected-claude-profile

    run_setup --profile claude --skip-plugins --yes

    assert_eq "1" "$SETUP_STATUS" "legacy claude profile should be rejected"
    assert_contains "Unknown profile: claude (valid: minimal, ai, full)" "$OUTPUT" \
        "rejection should identify canonical profiles"
}

test_full_profile_includes_ai() {
    new_case full-includes-ai

    run_setup --profile full --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "full profile should install successfully"
    [ -L "$HOME/.zshrc" ] || fail "full profile should include minimal config"
    [ -L "$HOME/.claude/CLAUDE.md" ] || fail "full profile should include Claude config"
    [ -f "$HOME/.cursor/cli-config.json" ] || fail "full profile should include Cursor preferences"
}

test_cursor_merge_preserves_live_machine_state() {
    new_case cursor-merge
    mkdir -p "$HOME/.cursor"
    cat >"$HOME/.cursor/cli-config.json" <<'JSON'
{
  "authInfo": {"email": "user@example.com"},
  "serverConfigCache": {"region": "local"},
  "privacyCache": {"enabled": true},
  "localOnly": {"keep": "me"},
  "permissions": ["Shell(git)", "Shell(ls)"],
  "approvalMode": "manual"
}
JSON

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "Cursor preferences should merge successfully"
    "$JQ_BIN" -e '
      .authInfo.email == "user@example.com" and
      .serverConfigCache.region == "local" and
      .privacyCache.enabled == true and
      .localOnly.keep == "me" and
      .permissions == ["Shell(git)", "Shell(ls)"] and
      .approvalMode == "auto-review"
    ' "$HOME/.cursor/cli-config.json" >/dev/null || fail "merge should preserve live machine state"
}

test_cursor_invalid_json_is_controlled() {
    new_case invalid-cursor-json
    mkdir -p "$HOME/.cursor"
    printf '{invalid\n' >"$HOME/.cursor/cli-config.json"

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "invalid live JSON should not abort setup under set -e"
    assert_contains "Failed to merge Cursor CLI config with jq" "$OUTPUT" \
        "invalid JSON should report the merge failure"
    assert_eq "{invalid" "$(tr -d '\n' <"$HOME/.cursor/cli-config.json")" \
        "invalid live config should remain untouched"
}

test_cursor_jq_failure_is_controlled() {
    new_case cursor-jq-failure
    mkdir -p "$HOME/.cursor"
    printf '{"authInfo":{"email":"safe@example.com"}}\n' >"$HOME/.cursor/cli-config.json"
    write_fake jq \
        'case "$*" in *cli-config.json*) exit 7 ;; esac' \
        "exec \"$JQ_BIN\" \"\$@\""

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "jq failure should not abort setup under set -e"
    assert_contains "Failed to merge Cursor CLI config with jq" "$OUTPUT" \
        "jq failure should be reported"
    assert_eq "safe@example.com" \
        "$("$JQ_BIN" -r '.authInfo.email' "$HOME/.cursor/cli-config.json")" \
        "failed merge should leave live config untouched"
}

test_cursor_symlink_target_is_refused() {
    new_case cursor-symlink
    mkdir -p "$HOME/.cursor" "$CASE_ROOT/external"
    printf '{"authInfo":{"email":"safe@example.com"}}\n' >"$CASE_ROOT/external/config.json"
    ln -s "$CASE_ROOT/external/config.json" "$HOME/.cursor/cli-config.json"

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "symlink refusal should be controlled"
    assert_contains "Refusing to merge Cursor CLI config into a symlink" "$OUTPUT" \
        "symlink refusal should be explicit"
    assert_eq "$CASE_ROOT/external/config.json" "$(readlink "$HOME/.cursor/cli-config.json")" \
        "Cursor config symlink should remain unchanged"
    assert_eq "safe@example.com" \
        "$("$JQ_BIN" -r '.authInfo.email' "$CASE_ROOT/external/config.json")" \
        "symlink target should not be modified"
}

test_tracked_cursor_config_has_no_permissions() {
    "$JQ_BIN" -e 'has("permissions") | not' "$REPO_ROOT/cursor/cli-config.json" >/dev/null \
        || fail "tracked Cursor preferences must never contain permissions"
}

test_setup_dry_run_is_noninteractive_on_linux_and_darwin() {
    local os
    for os in Linux Darwin; do
        new_case "dry-run-${os}"
        write_fake uname "printf '%s\\n' '$os'"

        run_setup --dry-run --profile full --skip-plugins --yes

        assert_eq "0" "$SETUP_STATUS" "$os non-TTY dry run should succeed"
        assert_contains "Running in dry-run mode" "$OUTPUT" "$os dry run should be reported"
        [ ! -e "$HOME/.cursor/cli-config.json" ] || fail "$os dry run must not write Cursor config"
    done
}

tests=(
    test_font_counter_survives_set_e
    test_root_apt_does_not_use_sudo
    test_partial_apt_failure_returns_nonzero
    test_starship_missing_from_apt_uses_official_installer
    test_starship_installer_failure_is_reported
    test_darwin_brew_install_failure_returns_nonzero
    test_tpm_installs_after_tmux_conf_is_linked
    test_ai_profile_installs_claude_and_cursor_config
    test_claude_profile_is_rejected
    test_full_profile_includes_ai
    test_cursor_merge_preserves_live_machine_state
    test_cursor_invalid_json_is_controlled
    test_cursor_jq_failure_is_controlled
    test_cursor_symlink_target_is_refused
    test_tracked_cursor_config_has_no_permissions
    test_setup_dry_run_is_noninteractive_on_linux_and_darwin
)

for test_name in "${tests[@]}"; do
    if ( "$test_name" ); then
        pass_count=$((pass_count + 1))
        printf 'ok %d - %s\n' "$pass_count" "$test_name"
    else
        failure_count=$((failure_count + 1))
        printf 'not ok - %s\n' "$test_name"
    fi
done

printf '1..%d\n' "${#tests[@]}"
[ "$failure_count" -eq 0 ]
