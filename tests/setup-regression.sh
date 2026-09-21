#!/usr/bin/env bash

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

new_case() {
    local name=$1
    CASE_ROOT="$TEST_ROOT/$name"
    HOME="$CASE_ROOT/home"
    FAKE_BIN="$CASE_ROOT/bin"
    OUTPUT="$CASE_ROOT/output"
    mkdir -p "$HOME" "$FAKE_BIN"
    export HOME
    PATH="$FAKE_BIN:$ORIGINAL_PATH"
    export PATH
}

run_setup() {
    set +e
    (
        cd "$REPO_ROOT"
        ./setup.sh "$@"
    ) >"$OUTPUT" 2>&1 </dev/null
    SETUP_STATUS=$?
    set -e
}

test_ai_profile_works_noninteractively() {
    new_case ai-profile

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "AI profile should install non-interactively"
    assert_contains "Active profiles: ai" "$OUTPUT" "AI profile should be canonical"
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

test_full_profile_includes_ai_and_minimal() {
    new_case full-profile

    run_setup --profile full --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "full profile should install successfully"
    [ -L "$HOME/.zshrc" ] || fail "full profile should include minimal config"
    [ -L "$HOME/.claude/CLAUDE.md" ] || fail "full profile should include Claude config"
    [ -f "$HOME/.cursor/cli-config.json" ] || fail "full profile should include Cursor preferences"
    [ -L "$HOME/.config/nvim" ] || fail "full profile should include Neovim config"
}

test_cursor_merge_preserves_machine_state_and_permissions() {
    new_case cursor-merge
    mkdir -p "$HOME/.cursor"
    cat >"$HOME/.cursor/cli-config.json" <<'JSON'
{
  "authInfo": {"email": "user@example.com"},
  "serverConfigCache": {"region": "local"},
  "permissions": ["Shell(git)", "Shell(ls)"],
  "approvalMode": "manual"
}
JSON

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "Cursor preferences should merge successfully"
    "$JQ_BIN" -e '
      .authInfo.email == "user@example.com" and
      .serverConfigCache.region == "local" and
      .permissions == ["Shell(git)", "Shell(ls)"] and
      .approvalMode == "auto-review"
    ' "$HOME/.cursor/cli-config.json" >/dev/null || fail "merge should preserve machine-local keys"
    "$JQ_BIN" -e 'has("permissions") | not' "$REPO_ROOT/cursor/cli-config.json" >/dev/null \
        || fail "tracked Cursor preferences must never store permissions"
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

test_invalid_cursor_json_is_controlled() {
    new_case invalid-cursor-json
    mkdir -p "$HOME/.cursor"
    printf '{invalid\n' >"$HOME/.cursor/cli-config.json"

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "invalid live JSON should not trigger an uncontrolled abort"
    assert_contains "Failed to merge Cursor CLI config with jq" "$OUTPUT" \
        "invalid JSON should report the merge failure"
    assert_eq "{invalid" "$(tr -d '\n' <"$HOME/.cursor/cli-config.json")" \
        "invalid live config should remain untouched"
}

test_jq_failure_is_controlled() {
    new_case jq-failure
    mkdir -p "$HOME/.cursor"
    printf '{"authInfo":{"email":"safe@example.com"}}\n' >"$HOME/.cursor/cli-config.json"
    printf '#!/usr/bin/env bash\nexit 7\n' >"$FAKE_BIN/jq"
    chmod +x "$FAKE_BIN/jq"

    run_setup --profile ai --skip-plugins --yes

    assert_eq "0" "$SETUP_STATUS" "jq failure should not trigger an uncontrolled abort"
    assert_contains "Failed to merge Cursor CLI config with jq" "$OUTPUT" \
        "jq failure should be reported"
    assert_eq "safe@example.com" \
        "$("$JQ_BIN" -r '.authInfo.email' "$HOME/.cursor/cli-config.json")" \
        "failed jq merge should leave live config untouched"
}

test_merge_helper_never_applies_tracked_permissions() {
    new_case tracked-permissions
    local source_file="$CASE_ROOT/source.json"
    local target_file="$CASE_ROOT/target.json"
    cat >"$source_file" <<'JSON'
{"approvalMode":"auto-review","permissions":["Shell(rm)"]}
JSON
    cat >"$target_file" <<'JSON'
{"authInfo":{"email":"safe@example.com"},"permissions":["Shell(git)"]}
JSON

    log_info() { :; }
    log_success() { :; }
    log_warning() { :; }
    log_error() { :; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    # shellcheck source=../lib/cursor-config.sh
    source "$REPO_ROOT/lib/cursor-config.sh"

    merge_cursor_cli_config "$source_file" "$target_file" false

    "$JQ_BIN" -e '
      .authInfo.email == "safe@example.com" and
      .permissions == ["Shell(git)"] and
      .approvalMode == "auto-review"
    ' "$target_file" >/dev/null || fail "tracked permissions must never overwrite live permissions"
}

tests=(
    test_ai_profile_works_noninteractively
    test_claude_profile_is_rejected
    test_full_profile_includes_ai_and_minimal
    test_cursor_merge_preserves_machine_state_and_permissions
    test_cursor_symlink_target_is_refused
    test_invalid_cursor_json_is_controlled
    test_jq_failure_is_controlled
    test_merge_helper_never_applies_tracked_permissions
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
