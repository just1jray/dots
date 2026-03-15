#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: run shellcheck on .sh files after Edit/Write
# Receives JSON on stdin with tool_name and tool_input fields

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$tool_name" == "Edit" || "$tool_name" == "Write" ]] || exit 0

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ "$file_path" == *.sh ]] || exit 0
[[ -f "$file_path" ]] || exit 0

# ShellCheck picks up .shellcheckrc from the file's directory tree automatically
output=$(/opt/homebrew/bin/shellcheck "$file_path" 2>&1) || {
    echo "shellcheck found issues:"
    echo "$output"
    exit 1
}
