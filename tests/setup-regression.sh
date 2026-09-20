#!/usr/bin/env bash
# Fake tools are written as single-quoted bash lines on purpose.
# shellcheck disable=SC2016

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ORIGINAL_PATH=$PATH
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

tests=(
    test_font_counter_survives_set_e
    test_root_apt_does_not_use_sudo
    test_partial_apt_failure_returns_nonzero
    test_starship_missing_from_apt_uses_official_installer
    test_starship_installer_failure_is_reported
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
