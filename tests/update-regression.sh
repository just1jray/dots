#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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
    if ! grep -F "$needle" "$file" >/dev/null; then
        fail "$message (missing '$needle')"
    fi
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
    cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$FAKE_BIN/git"
}

make_old_checkout() {
    local root=$1
    mkdir -p "$root/lib" "$root/zsh" "$root/btop/themes"
    : >"$root/setup.sh"
    : >"$root/lib/dots-root.sh"
    : >"$root/zsh/zshrc"
    : >"$root/btop/btop.conf"
    : >"$root/btop/themes/catppuccin_mocha.theme"
}

run_update() {
    set +e
    "$REPO_ROOT/update.sh" "$@" >"$OUTPUT" 2>&1
    UPDATE_STATUS=$?
    set -e
}

test_unrelated_symlink_is_preserved() {
    new_case unrelated-link
    mkdir -p "$CASE_ROOT/user"
    : >"$CASE_ROOT/user/zshrc"
    ln -s "$CASE_ROOT/user/zshrc" "$HOME/.zshrc"

    run_update --profile minimal

    assert_eq "0" "$UPDATE_STATUS" "unrelated symlink should not fail the update"
    assert_eq "$CASE_ROOT/user/zshrc" "$(readlink "$HOME/.zshrc")" \
        "unrelated symlink should remain unchanged"
    assert_contains "Leaving unrelated symlink in place: $HOME/.zshrc" "$OUTPUT" \
        "preservation should be reported"
}

test_old_checkout_is_detected_and_relinked() {
    new_case old-checkout
    local old_root="$CASE_ROOT/old-dots"
    make_old_checkout "$old_root"
    ln -s "$old_root/zsh/zshrc" "$HOME/.zshrc"

    run_update

    assert_eq "0" "$UPDATE_STATUS" "valid old checkout should relink cleanly"
    assert_contains "Active profiles: minimal" "$OUTPUT" "minimal profile should be detected"
    assert_eq "$REPO_ROOT/zsh/zshrc" "$(readlink "$HOME/.zshrc")" \
        "old checkout link should point to the current clone"
}

test_unrelated_dangling_suffix_is_rejected() {
    new_case unrelated-dangling
    ln -s "$CASE_ROOT/not-a-checkout/zsh/zshrc" "$HOME/.zshrc"

    run_update

    assert_eq "0" "$UPDATE_STATUS" "unrelated dangling link should not fail the update"
    assert_eq "$CASE_ROOT/not-a-checkout/zsh/zshrc" "$(readlink "$HOME/.zshrc")" \
        "suffix-only dangling link should remain unchanged"
    assert_contains "Leaving unrelated symlink in place: $HOME/.zshrc" "$OUTPUT" \
        "ambiguous dangling link should be reported"
}

test_dangling_claude_parent_is_controlled_failure() {
    new_case dangling-claude
    ln -s "$CASE_ROOT/missing-claude" "$HOME/.claude"

    run_update --profile claude

    assert_eq "1" "$UPDATE_STATUS" "dangling Claude parent should produce final failure"
    assert_eq "$CASE_ROOT/missing-claude" "$(readlink "$HOME/.claude")" \
        "dangling Claude parent should remain unchanged"
    assert_contains "Cannot relink Claude config through dangling symlink: $HOME/.claude" "$OUTPUT" \
        "dangling parent should have a clear error"
    assert_contains "relink failure" "$OUTPUT" "relink failure should reach final summary"
}

test_resolving_claude_parent_is_used() {
    new_case resolving-claude
    mkdir -p "$CASE_ROOT/cloud-claude"
    ln -s "$CASE_ROOT/cloud-claude" "$HOME/.claude"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "resolving Claude parent should remain usable"
    assert_eq "$CASE_ROOT/cloud-claude" "$(readlink "$HOME/.claude")" \
        "resolving Claude parent should remain unchanged"
    [ -L "$CASE_ROOT/cloud-claude/CLAUDE.md" ] || \
        fail "Claude config should be linked through the parent symlink"
}

test_btop_old_checkout_is_detected_and_relinked() {
    new_case btop-relink
    local old_root="$CASE_ROOT/old-dots"
    make_old_checkout "$old_root"
    mkdir -p "$HOME/.config/btop/themes"
    ln -s "$old_root/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    ln -s "$old_root/btop/themes/catppuccin_mocha.theme" \
        "$HOME/.config/btop/themes/catppuccin_mocha.theme"

    run_update

    assert_eq "0" "$UPDATE_STATUS" "btop links from an old checkout should relink"
    assert_contains "Active profiles: full" "$OUTPUT" "btop should identify the full profile"
    assert_eq "$REPO_ROOT/btop/btop.conf" "$(readlink "$HOME/.config/btop/btop.conf")" \
        "btop config should point to current clone"
    assert_eq "$REPO_ROOT/btop/themes/catppuccin_mocha.theme" \
        "$(readlink "$HOME/.config/btop/themes/catppuccin_mocha.theme")" \
        "Catppuccin Mocha btop theme should point to current clone"
}

test_relink_failures_are_aggregated() {
    new_case relink-failure
    cat >"$FAKE_BIN/ln" <<EOF
#!/usr/bin/env bash
if [ "\${*: -1}" = "$HOME/.zshrc" ]; then
    exit 1
fi
exec /bin/ln "\$@"
EOF
    chmod +x "$FAKE_BIN/ln"

    run_update --profile minimal

    assert_eq "1" "$UPDATE_STATUS" "a relink failure should produce final nonzero status"
    [ -L "$HOME/.gitconfig" ] || fail "safe links after a failed relink should still be created"
    assert_contains "Failed to link: $REPO_ROOT/zsh/zshrc -> $HOME/.zshrc" "$OUTPUT" \
        "failed relink should be reported"
    assert_contains "1 relink failure(s)" "$OUTPUT" \
        "relink failure count should reach final summary"
}

test_stale_managed_child_is_pruned() {
    new_case stale-child
    local old_root="$CASE_ROOT/old-dots"
    make_old_checkout "$old_root"
    mkdir -p "$old_root/llm/commands" "$HOME/.claude/commands"
    : >"$old_root/llm/commands/removed.md"
    ln -s "$old_root/llm/commands/removed.md" "$HOME/.claude/commands/removed.md"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "stale managed child should prune cleanly"
    [ ! -L "$HOME/.claude/commands/removed.md" ] || \
        fail "stale link proven to belong to an old checkout should be removed"
    assert_contains "Pruned stale managed symlink: $HOME/.claude/commands/removed.md" "$OUTPUT" \
        "managed stale-link pruning should be reported"
}

tests=(
    test_unrelated_symlink_is_preserved
    test_old_checkout_is_detected_and_relinked
    test_unrelated_dangling_suffix_is_rejected
    test_dangling_claude_parent_is_controlled_failure
    test_resolving_claude_parent_is_used
    test_btop_old_checkout_is_detected_and_relinked
    test_relink_failures_are_aggregated
    test_stale_managed_child_is_pruned
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
