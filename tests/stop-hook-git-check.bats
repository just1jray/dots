#!/usr/bin/env bats
# Tests for claude/hooks/stop-hook-git-check.sh

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_SCRIPT="${PROJECT_ROOT}/claude/hooks/stop-hook-git-check.sh"

setup() {
    load 'bats/bats-support/load'
    load 'bats/bats-assert/load'
    load 'helpers/common.bash'
    load 'helpers/git-mocks.bash'

    setup_temp_dir

    # Save original directory
    ORIGINAL_DIR="$(pwd)"
}

teardown() {
    # Return to original directory
    cd "$ORIGINAL_DIR" || true
    teardown_temp_dir
}

# =============================================================================
# Recursion prevention tests
# =============================================================================

@test "stop_hook_active: exits 0 when stop_hook_active is true" {
    run bash -c 'echo "{\"stop_hook_active\": true}" | '"$HOOK_SCRIPT"
    assert_success
    assert_output ""
}

@test "stop_hook_active: continues when stop_hook_active is false" {
    # Not in a git repo, so it will exit 0 after the git check
    run bash -c 'cd /tmp && echo "{\"stop_hook_active\": false}" | '"$HOOK_SCRIPT"
    assert_success
}

@test "stop_hook_active: continues when stop_hook_active is missing" {
    # Not in a git repo, so it will exit 0 after the git check
    run bash -c 'cd /tmp && echo "{}" | '"$HOOK_SCRIPT"
    assert_success
}

# =============================================================================
# Non-git repository handling tests
# =============================================================================

@test "non-git-repo: exits 0 when not in a git repository" {
    local non_git_dir="$TEST_TEMP_DIR/not_a_repo"
    mkdir -p "$non_git_dir"
    cd "$non_git_dir"

    run bash -c 'echo "{\"stop_hook_active\": false}" | '"$HOOK_SCRIPT"
    assert_success
    assert_output ""
}

@test "non-git-repo: exits 0 in temp directory" {
    cd "$TEST_TEMP_DIR"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_success
}

# =============================================================================
# Clean repository tests
# =============================================================================

@test "clean-repo: exits 0 when repository is clean and synced" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote)
    cd "$repo_dir"

    run bash -c 'echo "{\"stop_hook_active\": false}" | '"$HOOK_SCRIPT"
    assert_success
    assert_output ""
}

@test "clean-repo: exits 0 when repository has no remote but no local changes" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"

    run bash -c 'echo "{\"stop_hook_active\": false}" | '"$HOOK_SCRIPT"
    assert_success
}

# =============================================================================
# Uncommitted changes detection tests
# =============================================================================

@test "uncommitted-changes: exits 2 with unstaged changes" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_uncommitted_changes "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "uncommitted changes"
}

@test "uncommitted-changes: exits 2 with staged changes" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_staged_changes "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "uncommitted changes"
}

@test "uncommitted-changes: message goes to stderr" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_uncommitted_changes "$repo_dir"

    # Capture stderr only
    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"' 2>&1 >/dev/null'
    assert_output --partial "uncommitted changes"
}

# =============================================================================
# Untracked files detection tests
# =============================================================================

@test "untracked-files: exits 2 with untracked files" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_untracked_files "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "untracked files"
}

@test "untracked-files: ignores files in .gitignore" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"

    # Add .gitignore
    echo "ignored.txt" > .gitignore
    git add .gitignore
    git commit -m "Add gitignore" --quiet

    # Create ignored file
    echo "ignored content" > ignored.txt

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_success
}

# =============================================================================
# Unpushed commits detection tests
# =============================================================================

@test "unpushed-commits: exits 2 with unpushed commits on tracked branch" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote)
    cd "$repo_dir"
    create_unpushed_commit "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "unpushed commit"
}

@test "unpushed-commits: message includes commit count" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote)
    cd "$repo_dir"
    create_unpushed_commit "$repo_dir"
    create_unpushed_commit "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "2 unpushed commit"
}

@test "unpushed-commits: exits 2 on local branch without remote" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote)
    cd "$repo_dir"
    create_local_branch "$repo_dir" "feature-branch"
    create_unpushed_commit "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    assert_output --partial "no remote branch"
}

@test "unpushed-commits: message includes branch name" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote)
    cd "$repo_dir"
    create_unpushed_commit "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_failure 2
    # Should contain either 'main' or 'master'
    [[ "$output" == *"main"* ]] || [[ "$output" == *"master"* ]]
}

# =============================================================================
# Exit code tests
# =============================================================================

@test "exit-codes: returns 0 for clean state" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    assert_success
}

@test "exit-codes: returns 2 for any dirty state" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_uncommitted_changes "$repo_dir"

    run bash -c 'echo "{}" | '"$HOOK_SCRIPT"
    [ "$status" -eq 2 ]
}

@test "exit-codes: returns 0 when recursion prevention is active" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit)
    cd "$repo_dir"
    add_uncommitted_changes "$repo_dir"

    # Even with dirty state, should exit 0 due to recursion prevention
    run bash -c 'echo "{\"stop_hook_active\": true}" | '"$HOOK_SCRIPT"
    assert_success
}
