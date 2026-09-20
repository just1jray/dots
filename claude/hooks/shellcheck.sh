#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: run shellcheck on .sh files after Edit/Write
# Receives JSON on stdin with tool_name and tool_input fields

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$tool_name" == "Edit" || "$tool_name" == "Write" ]] || exit 0

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -n "$file_path" ]] || exit 0
[[ -f "$file_path" ]] || exit 0

# Homebrew on Apple Silicon is not the only install path.
shellcheck_bin=$(command -v shellcheck || true)
if [[ -z "$shellcheck_bin" ]]; then
    echo "shellcheck not on PATH; skipping."
    exit 0
fi

first_line=""
if [[ -s "$file_path" ]]; then
    read -r first_line < "$file_path" || true
fi

# Shell dotfiles carry no shebang, so the dialect has to be named explicitly;
# without -s shellcheck emits SC2148 on every one of them.
shell_opt=()

case "${file_path##*/}" in
    *.sh | *.bash) ;;
    .bashrc | .bash_profile | .bash_login | .bash_logout | .bash_aliases)
        [[ "$first_line" =~ ^#! ]] || shell_opt=(-s bash)
        ;;
    .profile | .shrc)
        [[ "$first_line" =~ ^#! ]] || shell_opt=(-s sh)
        ;;
    .kshrc)
        [[ "$first_line" =~ ^#! ]] || shell_opt=(-s ksh)
        ;;
    *)
        # Otherwise fall back to the shebang so extensionless scripts are
        # covered. shellcheck only supports sh/bash/dash/ksh, so anything
        # else (zsh, python, ...) is skipped rather than hard-erroring
        # on every edit.
        [[ "$first_line" =~ ^#! ]] || exit 0
        [[ "$first_line" =~ (^|[/[:space:]])(sh|bash|dash|ksh)([[:space:]]|$) ]] || exit 0
        ;;
esac

# ShellCheck picks up .shellcheckrc from the file's directory tree automatically
# exit 2 + stderr so the findings are fed back to Claude for fixing;
# exit 1 would only surface to the user and get skipped over
# ${arr[@]+"${arr[@]}"} so an empty array is safe under `set -u` on bash 3.2
output=$("$shellcheck_bin" ${shell_opt[@]+"${shell_opt[@]}"} "$file_path" 2>&1) || {
    echo "shellcheck found issues in $file_path:" >&2
    echo "$output" >&2
    exit 2
}
