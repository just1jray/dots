#!/bin/bash
# Git mock/factory functions for BATS tests

# Create a basic git repository
create_git_repo() {
    local repo_dir="${1:-$TEST_TEMP_DIR/repo}"
    mkdir -p "$repo_dir"
    git -C "$repo_dir" init --quiet
    git -C "$repo_dir" config user.email "test@example.com"
    git -C "$repo_dir" config user.name "Test User"
    echo "$repo_dir"
}

# Create a git repo with an initial commit
create_git_repo_with_commit() {
    local repo_dir
    repo_dir=$(create_git_repo "$1")
    echo "initial" > "$repo_dir/README.md"
    git -C "$repo_dir" add README.md
    git -C "$repo_dir" commit --quiet -m "Initial commit"
    echo "$repo_dir"
}

# Create a git repo with a remote origin
create_git_repo_with_remote() {
    local repo_dir
    repo_dir=$(create_git_repo_with_commit "$1")

    # Create a bare repo to act as remote
    local remote_dir="${TEST_TEMP_DIR}/remote_$(basename "$repo_dir")"
    git init --quiet --bare "$remote_dir"

    # Add as remote and push
    git -C "$repo_dir" remote add origin "$remote_dir"
    git -C "$repo_dir" push --quiet -u origin main 2>/dev/null || \
        git -C "$repo_dir" push --quiet -u origin master 2>/dev/null

    # Set up origin/HEAD to point to the default branch
    git -C "$repo_dir" remote set-head origin --auto >/dev/null 2>&1 || true

    echo "$repo_dir"
}

# Add uncommitted changes to a repo
add_uncommitted_changes() {
    local repo_dir="$1"
    echo "modified content" >> "$repo_dir/README.md"
}

# Add staged but uncommitted changes to a repo
add_staged_changes() {
    local repo_dir="$1"
    echo "staged content" >> "$repo_dir/README.md"
    git -C "$repo_dir" add README.md
}

# Add untracked files to a repo
add_untracked_files() {
    local repo_dir="$1"
    local filename="${2:-untracked.txt}"
    echo "untracked content" > "$repo_dir/$filename"
}

# Create an unpushed commit
create_unpushed_commit() {
    local repo_dir="$1"
    echo "new content" >> "$repo_dir/README.md"
    git -C "$repo_dir" add README.md
    git -C "$repo_dir" commit --quiet -m "Unpushed commit"
}

# Create a branch without upstream
create_local_branch() {
    local repo_dir="$1"
    local branch_name="${2:-feature-branch}"
    git -C "$repo_dir" checkout --quiet -b "$branch_name"
}

# Create JSON input for stop-hook-git-check.sh
create_hook_json() {
    local stop_hook_active="${1:-false}"
    echo "{\"stop_hook_active\": $stop_hook_active}"
}

# Create JSON input for context-bar.sh
create_context_bar_json() {
    local model="${1:-claude-opus-4-5}"
    local cwd="${2:-/tmp}"
    local context_window="${3:-200000}"
    local transcript_path="${4:-}"

    local json="{"
    json+="\"model\": {\"display_name\": \"$model\", \"id\": \"$model\"},"
    json+="\"cwd\": \"$cwd\","
    json+="\"context_window\": {\"context_window_size\": $context_window}"

    if [[ -n "$transcript_path" ]]; then
        json+=",\"transcript_path\": \"$transcript_path\""
    fi

    json+="}"
    echo "$json"
}

# Create a mock transcript file
create_mock_transcript() {
    local transcript_path="${1:-$TEST_TEMP_DIR/transcript.jsonl}"
    local input_tokens="${2:-50000}"

    cat > "$transcript_path" << EOF
{"type": "user", "message": {"content": "Hello, can you help me with something?"}}
{"type": "assistant", "message": {"content": "Sure, I'd be happy to help!", "usage": {"input_tokens": $input_tokens, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}}
EOF
    echo "$transcript_path"
}
