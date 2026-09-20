#!/usr/bin/env bash

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
    if ! grep -F "$needle" "$file" >/dev/null; then
        fail "$message (missing '$needle')"
    fi
}

new_case() {
    local name=$1
    local tool
    CASE_ROOT="$TEST_ROOT/$name"
    HOME="$CASE_ROOT/home"
    FAKE_BIN="$CASE_ROOT/bin"
    OUTPUT="$CASE_ROOT/output"
    mkdir -p "$HOME" "$FAKE_BIN"
    export HOME
    PATH="$FAKE_BIN:$ORIGINAL_PATH"
    export PATH
    # The suite must never reach the real plugin managers or the network.
    unset ZINIT_HOME
    for tool in git nvim tmux zsh; do
        printf '#!/bin/bash\nexit 0\n' >"$FAKE_BIN/$tool"
        chmod +x "$FAKE_BIN/$tool"
    done
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

# A checkout cloned before lib/dots-root.sh existed.
make_legacy_checkout() {
    local root=$1
    mkdir -p "$root/zsh" "$root/vim"
    : >"$root/setup.sh"
    : >"$root/zsh/zshrc"
    : >"$root/vim/vimrc"
}

run_update() {
    set +e
    "$REPO_ROOT/update.sh" "$@" >"$OUTPUT" 2>&1
    UPDATE_STATUS=$?
    set -e
}

# Restrict PATH to the fake bin so a tool removed from it is truly absent.
restrict_path_to_fake_bin() {
    local tool
    for tool in bash readlink dirname basename mkdir ln rm grep ls; do
        [ -e "$FAKE_BIN/$tool" ] || ln -s "$(command -v "$tool")" "$FAKE_BIN/$tool"
    done
    PATH="$FAKE_BIN"
    export PATH
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
    ln -s "$old_root/llm/commands/removed.md" "$HOME/.claude/commands/removed.md"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "stale managed child should prune cleanly"
    [ ! -L "$HOME/.claude/commands/removed.md" ] || \
        fail "stale link proven to belong to an old checkout should be removed"
    assert_contains "Pruned stale managed symlink: $HOME/.claude/commands/removed.md" "$OUTPUT" \
        "managed stale-link pruning should be reported"
}

test_neovim_refresh_failure_is_aggregated() {
    new_case nvim-failure
    printf '#!/bin/bash\nexit 1\n' >"$FAKE_BIN/nvim"
    chmod +x "$FAKE_BIN/nvim"

    run_update --profile full

    assert_eq "1" "$UPDATE_STATUS" "a Neovim refresh failure should produce final nonzero status"
    assert_contains "Neovim plugin refresh failed." "$OUTPUT" "Neovim failure should be reported"
    assert_contains "1 plugin refresh failure(s)" "$OUTPUT" \
        "refresh failure count should reach final summary"
}

test_legacy_checkout_without_lib_is_relinked() {
    new_case legacy-checkout
    local old_root="$CASE_ROOT/legacy-dots"
    make_legacy_checkout "$old_root"
    ln -s "$old_root/zsh/zshrc" "$HOME/.zshrc"
    ln -s "$old_root/vim/vimrc" "$HOME/.vimrc"

    run_update

    assert_eq "0" "$UPDATE_STATUS" "legacy checkout should relink cleanly"
    assert_contains "Active profiles: full" "$OUTPUT" \
        "vimrc from a legacy checkout should identify the full profile"
    assert_eq "$REPO_ROOT/zsh/zshrc" "$(readlink "$HOME/.zshrc")" \
        "legacy zshrc link should point to the current clone"
    assert_eq "$REPO_ROOT/vim/vimrc" "$(readlink "$HOME/.vimrc")" \
        "legacy vimrc link should point to the current clone"
}

test_resolving_managed_link_is_not_pruned() {
    new_case resolving-managed
    local old_root="$CASE_ROOT/old-dots"
    make_old_checkout "$old_root"
    mkdir -p "$old_root/llm/commands" "$HOME/.claude/commands"
    : >"$old_root/llm/commands/local-only.md"
    ln -s "$old_root/llm/commands/local-only.md" "$HOME/.claude/commands/local-only.md"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "a resolving managed link should not fail the update"
    assert_eq "$old_root/llm/commands/local-only.md" \
        "$(readlink "$HOME/.claude/commands/local-only.md")" \
        "managed link with an intact target must not be pruned"
    assert_contains \
        "Leaving managed symlink whose source is missing from this clone: $HOME/.claude/commands/local-only.md" \
        "$OUTPUT" "skipped prune should be reported"
}

test_dry_run_reports_relink_failures() {
    new_case dry-run-failure
    ln -s "$CASE_ROOT/missing-claude" "$HOME/.claude"

    run_update --dry-run --profile claude

    assert_eq "1" "$UPDATE_STATUS" "dry run should exit nonzero when the real run would fail"
    assert_contains "Dry run found 1 relink failure(s). No changes were made." "$OUTPUT" \
        "dry run should summarise relink failures"
    assert_eq "$CASE_ROOT/missing-claude" "$(readlink "$HOME/.claude")" \
        "dry run must not modify anything"
}

test_managed_skills_symlink_becomes_real_dir() {
    new_case managed-skills-link
    local old_root="$CASE_ROOT/old-dots"
    make_old_checkout "$old_root"
    mkdir -p "$old_root/llm/skills" "$HOME/.claude"
    ln -s "$old_root/llm/skills" "$HOME/.claude/skills"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "managed skills symlink should convert cleanly"
    if [ -L "$HOME/.claude/skills" ] || [ ! -d "$HOME/.claude/skills" ]; then
        fail "skills should become a real directory"
    fi
    [ -n "$(ls -A "$HOME/.claude/skills")" ] || fail "skills should be linked into the new directory"
    [ -z "$(ls -A "$old_root/llm/skills")" ] || fail "nothing may be written into the old checkout"
    assert_contains "Replaced managed directory symlink with a real directory: $HOME/.claude/skills" \
        "$OUTPUT" "conversion should be reported"
}

test_unrelated_skills_symlink_is_not_written_into() {
    new_case unrelated-skills-link
    mkdir -p "$CASE_ROOT/other-tool/skills" "$HOME/.claude"
    ln -s "$CASE_ROOT/other-tool/skills" "$HOME/.claude/skills"

    run_update --profile claude

    assert_eq "0" "$UPDATE_STATUS" "unrelated skills symlink should be a warning, not a failure"
    assert_eq "$CASE_ROOT/other-tool/skills" "$(readlink "$HOME/.claude/skills")" \
        "unrelated skills symlink should remain unchanged"
    [ -z "$(ls -A "$CASE_ROOT/other-tool/skills")" ] || \
        fail "nothing may be written through an unrelated directory symlink"
    assert_contains "Leaving unrelated directory symlink in place; not linking into it: $HOME/.claude/skills" \
        "$OUTPUT" "skip should be reported"
}

test_tpm_refresh_skips_without_tmux() {
    new_case tpm-no-tmux
    mkdir -p "$HOME/.tmux/plugins/tpm/bin"
    printf '#!/bin/bash\n: >"%s/updater-ran"\nexit 1\n' "$CASE_ROOT" \
        >"$HOME/.tmux/plugins/tpm/bin/update_plugins"
    chmod +x "$HOME/.tmux/plugins/tpm/bin/update_plugins"
    rm "$FAKE_BIN/tmux"
    restrict_path_to_fake_bin

    run_update --profile full

    assert_eq "0" "$UPDATE_STATUS" "missing tmux should skip TPM, not fail"
    assert_contains "tmux is not installed; skipping TPM refresh." "$OUTPUT" "skip should be reported"
    [ ! -e "$CASE_ROOT/updater-ran" ] || fail "TPM updater must not run without tmux"
}

test_setup_through_symlinked_clone_needs_no_relink() {
    new_case symlinked-clone
    ln -s "$REPO_ROOT" "$CASE_ROOT/clone"
    (cd "$CASE_ROOT/clone" && ./setup.sh --profile minimal --skip-plugins --yes \
        >"$CASE_ROOT/setup-output" 2>&1) \
        || fail "setup.sh through a symlinked clone should succeed"

    run_update --dry-run

    assert_eq "0" "$UPDATE_STATUS" "dry run after setup should succeed"
    assert_contains "Config links already point at this clone." "$OUTPUT" \
        "setup and update must agree on the clone path"
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
    test_neovim_refresh_failure_is_aggregated
    test_legacy_checkout_without_lib_is_relinked
    test_resolving_managed_link_is_not_pruned
    test_dry_run_reports_relink_failures
    test_managed_skills_symlink_becomes_real_dir
    test_unrelated_skills_symlink_is_not_written_into
    test_tpm_refresh_skips_without_tmux
    test_setup_through_symlinked_clone_needs_no_relink
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
