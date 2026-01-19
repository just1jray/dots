#!/bin/bash
# Common test helpers for BATS tests

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load BATS helper libraries
load_bats_libs() {
    load "${PROJECT_ROOT}/tests/bats/bats-support/load"
    load "${PROJECT_ROOT}/tests/bats/bats-assert/load"
}

# Create a temporary directory for test isolation
setup_temp_dir() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR"
}

# Clean up the temporary directory
teardown_temp_dir() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    if [[ -n "$ORIGINAL_HOME" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

# Create directory structure needed for setup.sh
setup_home_structure() {
    mkdir -p "$HOME/.config/zsh"
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.tmux/plugins"
    mkdir -p "$HOME/Developer/src"
    mkdir -p "$HOME/.claude"
}

# Mock command to simulate missing commands
mock_missing_command() {
    local cmd="$1"
    # Create a wrapper that returns false
    eval "${cmd}() { return 1; }"
    export -f "$cmd"
}

# Mock command to simulate existing commands
mock_existing_command() {
    local cmd="$1"
    local output="${2:-}"
    # Create a wrapper that returns true and optionally echoes output
    if [[ -n "$output" ]]; then
        eval "${cmd}() { echo '$output'; return 0; }"
    else
        eval "${cmd}() { return 0; }"
    fi
    export -f "$cmd"
}
