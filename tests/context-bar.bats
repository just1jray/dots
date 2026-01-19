#!/usr/bin/env bats
# Tests for claude/scripts/context-bar.sh

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CONTEXT_BAR_SCRIPT="${PROJECT_ROOT}/claude/scripts/context-bar.sh"

setup() {
    load 'bats/bats-support/load'
    load 'bats/bats-assert/load'
    load 'helpers/common.bash'
    load 'helpers/git-mocks.bash'

    setup_temp_dir
}

teardown() {
    teardown_temp_dir
}

# Helper to run the context bar script with JSON input
run_context_bar() {
    local json="$1"
    run bash -c "echo '$json' | $CONTEXT_BAR_SCRIPT"
}

# =============================================================================
# Model name extraction tests
# =============================================================================

@test "model-name: extracts display_name from model" {
    local json
    json=$(create_context_bar_json "Claude Opus 4.5" "$TEST_TEMP_DIR")
    run_context_bar "$json"
    assert_success
    assert_output --partial "Claude Opus 4.5"
}

@test "model-name: falls back to id when display_name missing" {
    local json='{"model": {"id": "claude-opus-4-5"}, "cwd": "/tmp", "context_window": {"context_window_size": 200000}}'
    run_context_bar "$json"
    assert_success
    assert_output --partial "claude-opus-4-5"
}

@test "model-name: shows ? when model info missing" {
    local json='{"cwd": "/tmp", "context_window": {"context_window_size": 200000}}'
    run_context_bar "$json"
    assert_success
    assert_output --partial "?"
}

# =============================================================================
# Directory name extraction tests
# =============================================================================

@test "dir-name: extracts basename from cwd" {
    local json
    json=$(create_context_bar_json "claude" "/Users/test/my-project")
    run_context_bar "$json"
    assert_success
    assert_output --partial "my-project"
}

@test "dir-name: handles paths with spaces" {
    mkdir -p "$TEST_TEMP_DIR/my project"
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR/my project")
    run_context_bar "$json"
    assert_success
    assert_output --partial "my project"
}

@test "dir-name: shows folder emoji" {
    local json
    json=$(create_context_bar_json "claude" "/tmp/test")
    run_context_bar "$json"
    assert_success
    assert_output --partial "📁"
}

# =============================================================================
# Git branch detection tests
# =============================================================================

@test "git-branch: shows branch name in git repo" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    # Should show either main or master
    [[ "$output" == *"main"* ]] || [[ "$output" == *"master"* ]]
}

@test "git-branch: shows branch emoji" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "🔀"
}

@test "git-branch: no branch info for non-git directory" {
    mkdir -p "$TEST_TEMP_DIR/not-a-repo"
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR/not-a-repo")
    run_context_bar "$json"
    assert_success
    refute_output --partial "🔀"
}

# =============================================================================
# Uncommitted file count tests
# =============================================================================

@test "uncommitted-count: shows 0 files when clean" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "0 files uncommitted"
}

@test "uncommitted-count: counts modified files" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    add_uncommitted_changes "$repo_dir"
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "uncommitted"
}

@test "uncommitted-count: shows filename when only one file" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    add_untracked_files "$repo_dir" "single-file.txt"
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "single-file.txt"
}

@test "uncommitted-count: shows count when multiple files" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    add_untracked_files "$repo_dir" "file1.txt"
    add_untracked_files "$repo_dir" "file2.txt"
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "files uncommitted"
}

# =============================================================================
# Sync status tests
# =============================================================================

@test "sync-status: shows no upstream for local-only repo" {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$TEST_TEMP_DIR/repo")
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "no upstream"
}

@test "sync-status: shows synced when up to date" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote "$TEST_TEMP_DIR/repo")
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "synced"
}

@test "sync-status: shows ahead count" {
    local repo_dir
    repo_dir=$(create_git_repo_with_remote "$TEST_TEMP_DIR/repo")
    create_unpushed_commit "$repo_dir"
    local json
    json=$(create_context_bar_json "claude" "$repo_dir")
    run_context_bar "$json"
    assert_success
    assert_output --partial "ahead"
}

# =============================================================================
# Context percentage calculation tests
# =============================================================================

@test "context-pct: shows percentage of context used" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000)
    run_context_bar "$json"
    assert_success
    assert_output --partial "% of"
}

@test "context-pct: shows token count in k format" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000)
    run_context_bar "$json"
    assert_success
    assert_output --partial "200k tokens"
}

@test "context-pct: handles smaller context windows" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 100000)
    run_context_bar "$json"
    assert_success
    assert_output --partial "100k tokens"
}

@test "context-pct: shows approximate percentage without transcript" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000)
    run_context_bar "$json"
    assert_success
    # Should show ~ prefix for approximate
    assert_output --partial "~"
}

@test "context-pct: calculates from transcript when available" {
    local transcript_path
    transcript_path=$(create_mock_transcript "$TEST_TEMP_DIR/transcript.jsonl" 50000)
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "% of 200k tokens"
}

# =============================================================================
# Progress bar rendering tests
# =============================================================================

@test "progress-bar: renders bar characters" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000)
    run_context_bar "$json"
    assert_success
    # Should contain bar characters (█, ▄, or ░)
    [[ "$output" == *"█"* ]] || [[ "$output" == *"▄"* ]] || [[ "$output" == *"░"* ]]
}

@test "progress-bar: shows empty bar at conversation start" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000)
    run_context_bar "$json"
    assert_success
    # At start (~10% baseline), most of bar should be empty
    assert_output --partial "░"
}

# =============================================================================
# Last user message extraction tests
# =============================================================================

@test "last-message: shows last user message when transcript exists" {
    local transcript_path="$TEST_TEMP_DIR/transcript.jsonl"
    cat > "$transcript_path" << 'EOF'
{"type": "user", "message": {"content": "First message"}}
{"type": "assistant", "message": {"content": "Response", "usage": {"input_tokens": 100}}}
{"type": "user", "message": {"content": "Hello, can you help me?"}}
{"type": "assistant", "message": {"content": "Sure!", "usage": {"input_tokens": 200}}}
EOF
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "Hello, can you help me?"
}

@test "last-message: shows speech bubble emoji" {
    local transcript_path="$TEST_TEMP_DIR/transcript.jsonl"
    cat > "$transcript_path" << 'EOF'
{"type": "user", "message": {"content": "Test message"}}
{"type": "assistant", "message": {"content": "Response", "usage": {"input_tokens": 100}}}
EOF
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "💬"
}

@test "last-message: skips interrupted request messages" {
    local transcript_path="$TEST_TEMP_DIR/transcript.jsonl"
    cat > "$transcript_path" << 'EOF'
{"type": "user", "message": {"content": "Good message"}}
{"type": "assistant", "message": {"content": "Response", "usage": {"input_tokens": 100}}}
{"type": "user", "message": {"content": "[Request interrupted by user]"}}
EOF
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "Good message"
    refute_output --partial "interrupted"
}

@test "last-message: truncates long messages" {
    local transcript_path="$TEST_TEMP_DIR/transcript.jsonl"
    local long_msg="This is a very long message that should be truncated because it exceeds the maximum length allowed for display in the context bar which needs to fit on a single line of the terminal without wrapping around"
    cat > "$transcript_path" << EOF
{"type": "user", "message": {"content": "$long_msg"}}
{"type": "assistant", "message": {"content": "Response", "usage": {"input_tokens": 100}}}
EOF
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "..."
}

@test "last-message: handles array content format" {
    local transcript_path="$TEST_TEMP_DIR/transcript.jsonl"
    cat > "$transcript_path" << 'EOF'
{"type": "user", "message": {"content": [{"type": "text", "text": "Array format message"}]}}
{"type": "assistant", "message": {"content": "Response", "usage": {"input_tokens": 100}}}
EOF
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR" 200000 "$transcript_path")
    run_context_bar "$json"
    assert_success
    assert_output --partial "Array format message"
}

# =============================================================================
# Color theme tests
# =============================================================================

@test "color-theme: outputs ANSI escape codes" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR")
    run_context_bar "$json"
    assert_success
    # Should contain ANSI escape sequences
    [[ "$output" == *$'\033['* ]] || [[ "$output" == *$'\e['* ]]
}

@test "color-theme: includes reset code" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR")
    run_context_bar "$json"
    assert_success
    # Should reset colors at end
    [[ "$output" == *"[0m"* ]]
}

# =============================================================================
# Output format tests
# =============================================================================

@test "output-format: separates sections with pipes" {
    local json
    json=$(create_context_bar_json "claude" "$TEST_TEMP_DIR")
    run_context_bar "$json"
    assert_success
    assert_output --partial " | "
}

@test "output-format: model comes first" {
    local json
    json=$(create_context_bar_json "MyModel" "$TEST_TEMP_DIR")
    run_context_bar "$json"
    assert_success
    # Model should be near the start of output (after any ANSI codes)
    [[ "$output" == *"MyModel"*"|"* ]]
}
