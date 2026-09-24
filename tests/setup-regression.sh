#!/usr/bin/env bash
# Fake tools are written as single-quoted bash lines on purpose.
# shellcheck disable=SC2016

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
JQ_BIN=$(command -v jq)
TEST_ROOT=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TEST_ROOT"' EXIT

# setup.sh skips packages whose command is already on PATH, so the host's own
# zsh, git, or starship must not leak in. Each case gets its fake bin plus
# only these general-purpose tools.
TOOLS_BIN="$TEST_ROOT/tools"
mkdir -p "$TOOLS_BIN"
for tool in bash sh env cat cp mv rm ln mkdir chmod touch date readlink dirname \
    basename mktemp cmp head tail grep sed tr sort wc ls jq; do
    tool_path=$(command -v "$tool") || { printf 'missing test tool: %s\n' "$tool" >&2; exit 1; }
    ln -s "$tool_path" "$TOOLS_BIN/$tool"
done

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

count_matches() {
    grep -c -F "$1" "$2" || true
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
    PATH="$FAKE_BIN:$TOOLS_BIN"
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
    for command_name in vim tmux fc-cache brew; do
        write_fake "$command_name" 'exit 0'
    done
    write_fake nvim \
        'if [ "${1:-}" = "--version" ]; then printf "%s\n" "NVIM v0.test"; fi' \
        'exit 0'
}

# Commands a minimal profile would otherwise install.
fake_minimal_commands() {
    local command_name
    for command_name in git zsh starship fzf zoxide; do
        write_fake "$command_name" 'exit 0'
    done
}

run_setup() {
    set +e
    (
        cd "$REPO_ROOT"
        "$BASH" ./setup.sh "$@"
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
    assert_contains "apt-get install -y fzf" "$TOOL_LOG" "fzf should be installed"
    assert_contains "apt-get install -y zoxide" "$TOOL_LOG" "zoxide should be installed"
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

    assert_eq "1" "$SETUP_STATUS" "invalid live JSON should be a reported failure"
    assert_contains "Setup finished with failures: Cursor CLI config merge" "$OUTPUT" \
        "setup should reach the final summary instead of aborting"
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

    assert_eq "1" "$SETUP_STATUS" "jq failure should be a reported failure"
    assert_contains "Cursor CLI config merge" "$OUTPUT" \
        "setup should reach the final summary instead of aborting"
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

    assert_eq "1" "$SETUP_STATUS" "symlink refusal should be a reported failure"
    assert_contains "Setup finished with failures: Cursor CLI config merge" "$OUTPUT" \
        "the final summary should name the Cursor merge"
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

test_setup_from_another_cwd_links_this_clone() {
    new_case other-cwd
    fake_minimal_commands

    set +e
    (cd "$CASE_ROOT" && "$BASH" "$REPO_ROOT/setup.sh" --profile minimal --skip-plugins) \
        >"$OUTPUT" 2>&1
    SETUP_STATUS=$?
    set -e

    assert_eq "0" "$SETUP_STATUS" "setup run from another directory should succeed"
    assert_eq "$REPO_ROOT/zsh/zshrc" "$(readlink "$HOME/.zshrc")" \
        "links must point into the clone containing setup.sh, not the cwd"
    assert_eq "$REPO_ROOT/git/gitconfig" "$(readlink "$HOME/.gitconfig")" \
        "gitconfig should be linked from the clone"
}

test_missing_source_is_a_failure() {
    new_case missing-source
    fake_minimal_commands
    local clone="$CASE_ROOT/clone"
    mkdir -p "$clone"
    cp -R "$REPO_ROOT/." "$clone"
    rm -f "$clone/starship/starship.toml"

    set +e
    "$BASH" "$clone/setup.sh" --profile minimal --skip-plugins >"$OUTPUT" 2>&1
    SETUP_STATUS=$?
    set -e

    assert_eq "1" "$SETUP_STATUS" "a missing required source must fail setup"
    assert_contains "Source file does not exist: $clone/starship/starship.toml" "$OUTPUT" \
        "the missing source should be named"
    assert_contains "Setup finished with failures: 1 config link(s)" "$OUTPUT" \
        "the final summary should count the failed link"
    assert_not_contains "Setup completed successfully!" "$OUTPUT" "setup must not print success"
    [ -L "$HOME/.zshrc" ] || fail "other links should still be created"
}

test_rerun_leaves_correct_links_alone() {
    new_case rerun
    fake_minimal_commands

    run_setup --profile minimal --skip-plugins
    assert_eq "0" "$SETUP_STATUS" "first run should succeed"
    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "second run should succeed"
    assert_not_contains "Removed existing symlink" "$OUTPUT" \
        "correct links must not be removed and recreated"
    assert_not_contains "Linked: " "$OUTPUT" "correct links must not be relinked"
}

test_foreign_symlink_is_backed_up() {
    new_case foreign-link
    fake_minimal_commands
    mkdir -p "$CASE_ROOT/user"
    : >"$CASE_ROOT/user/zshrc"
    ln -s "$CASE_ROOT/user/zshrc" "$HOME/.zshrc"

    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "a foreign symlink should be backed up, not fail setup"
    assert_eq "$REPO_ROOT/zsh/zshrc" "$(readlink "$HOME/.zshrc")" "zshrc should be linked"
    local backup
    for backup in "$HOME"/.zshrc.old_*; do
        [ -L "$backup" ] || fail "the foreign symlink should be kept as a backup"
        assert_eq "$CASE_ROOT/user/zshrc" "$(readlink "$backup")" \
            "the backup should still point at the user's file"
    done
}

test_managed_symlink_from_old_checkout_is_replaced() {
    new_case old-checkout-link
    fake_minimal_commands
    local old_root="$CASE_ROOT/old-dots"
    mkdir -p "$old_root/zsh"
    : >"$old_root/setup.sh"
    : >"$old_root/zsh/zshrc"
    ln -s "$old_root/zsh/zshrc" "$HOME/.zshrc"

    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "relinking an old checkout should succeed"
    assert_eq "$REPO_ROOT/zsh/zshrc" "$(readlink "$HOME/.zshrc")" "zshrc should be relinked"
    if ls "$HOME"/.zshrc.old_* >/dev/null 2>&1; then
        fail "a link into another dots checkout needs no backup"
    fi
}

test_present_packages_skip_apt() {
    new_case packages-present
    fake_minimal_commands

    run_setup --profile minimal --skip-plugins

    assert_eq "0" "$SETUP_STATUS" "setup with every package present should succeed"
    assert_not_contains "apt-get" "$TOOL_LOG" "apt must not run when nothing is missing"
    assert_contains "Profile packages already installed: zsh git starship fzf zoxide" "$OUTPUT" \
        "skipped packages should be reported"
}

test_old_nvim_is_flagged() {
    new_case old-nvim
    write_fake nvim \
        'if [ "${1:-}" = "--version" ]; then printf "%s\n" "NVIM v0.9.5"; fi' \
        'exit 0'

    run_setup --profile full --skip-plugins

    assert_contains "NVIM v0.9.5 is older than 0.10" "$OUTPUT" "an old Neovim should be flagged"
}

test_claude_hook_merge_is_idempotent() {
    new_case hook-idempotent
    mkdir -p "$HOME/.claude"
    cat >"$HOME/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "Notification": [
      {"hooks": [{"type": "command", "command": "notify-send claude"}]}
    ]
  }
}
EOF

    run_setup --profile ai
    assert_eq "0" "$SETUP_STATUS" "ai setup should succeed"
    cp "$HOME/.claude/settings.json" "$CASE_ROOT/first.json"
    run_setup --profile ai

    assert_eq "0" "$SETUP_STATUS" "second ai setup should succeed"
    cmp -s "$CASE_ROOT/first.json" "$HOME/.claude/settings.json" || \
        fail "a second merge must leave settings.json byte-identical"
    assert_eq "opus" "$(jq -r .model "$HOME/.claude/settings.json")" \
        "unrelated settings must be preserved"
    assert_eq "notify-send claude" \
        "$(jq -r '.hooks.Notification[0].hooks[0].command' "$HOME/.claude/settings.json")" \
        "unrelated hook entries must be preserved"
    assert_eq "1" "$(count_matches "block-force-push.sh" "$HOME/.claude/settings.json")" \
        "each managed hook should appear once"
}

test_claude_hook_merge_replaces_managed_entries() {
    new_case hook-replace
    local installed_hooks="$HOME/.claude/hooks"
    mkdir -p "$HOME/.claude"
    cat >"$CASE_ROOT/fragment.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [
        {"type": "command", "command": "bash '{{CLAUDE_HOOKS}}/block-force-push.sh'", "timeout": 10}
      ]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash '{{CLAUDE_HOOKS}}/stop-hook-git-check.sh'"}]}
    ]
  }
}
EOF
    cat >"$HOME/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [
        {"type": "command", "command": "bash $installed_hooks/block-force-push.sh", "timeout": 5},
        {"type": "command", "command": "my-guard.sh"}
      ]},
      {"matcher": "Read", "hooks": [
        {"type": "command", "command": "bash ~/tools/block-force-push.sh"}
      ]}
    ]
  }
}
EOF

    (
        DRY_RUN=false
        log_info() { :; }
        log_success() { :; }
        log_warning() { printf '%s\n' "$1"; }
        command_exists() { command -v "$1" >/dev/null 2>&1; }
        # shellcheck source=lib/claude-hooks.sh
        source "$REPO_ROOT/lib/claude-hooks.sh"
        merge_claude_hooks "$CASE_ROOT/fragment.json" "$HOME/.claude/settings.json" "$installed_hooks"
    ) >"$OUTPUT" 2>&1 || fail "merge should succeed"

    local settings="$HOME/.claude/settings.json"
    assert_eq "10" \
        "$(jq '[.hooks.PreToolUse[].hooks[] | select(.command | test("hooks/block-force-push")) | .timeout | tostring] | join(",")' -r "$settings")" \
        "the managed entry should be replaced with the new timeout"
    assert_eq "bash '$installed_hooks/block-force-push.sh'" \
        "$(jq -r '[.hooks.PreToolUse[].hooks[] | select(.timeout == 10)][0].command' "$settings")" \
        "the managed entry should use the fragment's quoted command"
    assert_eq "my-guard.sh" \
        "$(jq -r '[.hooks.PreToolUse[].hooks[] | select(.command == "my-guard.sh")][0].command' "$settings")" \
        "an unrelated hook in the same group must be preserved"
    assert_eq "bash ~/tools/block-force-push.sh" \
        "$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "Read")][0].hooks[0].command' "$settings")" \
        "a same-named script outside the hooks directory is not managed"
    assert_eq "bash '$installed_hooks/stop-hook-git-check.sh'" \
        "$(jq -r '.hooks.Stop[0].hooks[0].command' "$settings")" \
        "any event type should merge"
    ls "$settings".old_* >/dev/null 2>&1 || fail "settings.json should be backed up before writing"
}

test_invalid_settings_json_does_not_abort() {
    new_case hook-invalid-json
    mkdir -p "$HOME/.claude"
    printf '{ not json\n' >"$HOME/.claude/settings.json"

    run_setup --profile ai

    assert_eq "1" "$SETUP_STATUS" "a failed hook merge should be reported in the exit status"
    assert_contains "is not valid JSON; skipping hook merge" "$OUTPUT" "the bad file should be named"
    assert_contains "Setup finished with failures: Claude hook merge" "$OUTPUT" \
        "the final summary should name the failed step"
    assert_eq "{ not json" "$(cat "$HOME/.claude/settings.json")" \
        "invalid settings.json must be left untouched"
    [ -L "$HOME/.claude/skills/code-review-edu" ] || \
        fail "setup should continue linking after the failed merge"
}

test_skill_backups_stay_outside_skills_dir() {
    new_case skill-backup
    mkdir -p "$HOME/.claude/skills/code-review-edu"
    : >"$HOME/.claude/skills/code-review-edu/SKILL.md"

    run_setup --profile ai

    assert_eq "0" "$SETUP_STATUS" "ai setup should succeed"
    [ -L "$HOME/.claude/skills/code-review-edu" ] || fail "the skill should be linked"
    if ls -d "$HOME"/.claude/skills/*.backup_* >/dev/null 2>&1; then
        fail "backups inside skills/ would load as duplicate skills"
    fi
    ls -d "$HOME"/.claude/skills.backup/code-review-edu.backup_* >/dev/null 2>&1 || \
        fail "the old skill should be backed up to skills.backup/"
}

test_devices_env_template_is_copied_once() {
    new_case devices-env
    local target="$HOME/.config/homelab/devices.env"

    run_setup --profile ai
    assert_eq "0" "$SETUP_STATUS" "ai setup should succeed"
    cmp -s "$REPO_ROOT/llm/devices.env.template" "$target" || \
        fail "the devices template should be copied"
    printf 'ROUTER_HOST=10.0.0.1\n' >"$target"
    run_setup --profile ai

    assert_eq "ROUTER_HOST=10.0.0.1" "$(cat "$target")" "an existing devices.env must not be overwritten"
}

test_tpm_clone_failure_does_not_abort() {
    new_case tpm-offline
    write_fake git \
        'if [ "$1" = clone ]; then exit 128; fi' \
        'exit 0'

    run_setup --profile full

    assert_eq "1" "$SETUP_STATUS" "a failed TPM clone should be reported in the exit status"
    assert_contains "Setup finished with failures: Tmux Plugin Manager install" "$OUTPUT" \
        "the final summary should name the failed step"
    assert_contains "Could not clone Catppuccin vim theme" "$OUTPUT" \
        "the vim theme clone failure should only warn"
    assert_contains "Checking NVChad installation" "$OUTPUT" "later steps should still run"
}

test_vim_catppuccin_is_cloned_once() {
    new_case vim-theme
    write_fake git \
        'printf "git %s\n" "$*" >>"$TOOL_LOG"' \
        'if [ "$1" = clone ]; then mkdir -p "${@: -1}"; fi' \
        'exit 0'

    run_setup --profile full
    run_setup --profile full

    assert_eq "1" "$(count_matches "clone --depth=1 https://github.com/catppuccin/vim $HOME/.vim/pack/themes/start/catppuccin" "$TOOL_LOG")" \
        "the Catppuccin vim theme should be cloned shallowly, once"
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
    test_setup_from_another_cwd_links_this_clone
    test_missing_source_is_a_failure
    test_rerun_leaves_correct_links_alone
    test_foreign_symlink_is_backed_up
    test_managed_symlink_from_old_checkout_is_replaced
    test_present_packages_skip_apt
    test_old_nvim_is_flagged
    test_claude_hook_merge_is_idempotent
    test_claude_hook_merge_replaces_managed_entries
    test_invalid_settings_json_does_not_abort
    test_skill_backups_stay_outside_skills_dir
    test_devices_env_template_is_copied_once
    test_tpm_clone_failure_does_not_abort
    test_vim_catppuccin_is_cloned_once
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
