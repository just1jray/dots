#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: deny git force-pushes wherever the flag sits in the command.
# Permission deny rules match on command prefix only, so `Bash(git push --force:*)`
# misses `git push origin main --force`. This inspects the whole command string.
# Receives JSON on stdin with tool_name and tool_input fields.
# Best-effort: aliases, `$(echo -f)` and similar indirection are not caught.

# Set to 1 to permit --force-with-lease / --force-if-includes (the safer variants).
ALLOW_LEASE=0

input=$(cat)

# Fail closed: without jq (or with unparseable input) fall back to a coarse
# scan of the raw payload, blocking anything that looks like a forced push.
fallback() {
    [[ "$input" == *push* ]] || exit 0
    if [[ "$input" =~ git.*push ]] &&
        [[ "$input" =~ (^|[^[:alnum:]])(-[[:alnum:]]*f|--force|--mirror|\+[^[:space:]]) ]]; then
        printf '%s\n' "Force push blocked by block-force-push.sh ($1; raw input looks like a forced git push). Use a normal push, or edit the hook if this is intentional." >&2
        exit 2
    fi
    exit 0
}

command -v jq >/dev/null 2>&1 || fallback "jq not found"
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || fallback "invalid hook input"
[[ -z "$tool_name" || "$tool_name" == "Bash" ]] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || fallback "invalid hook input"
[[ -n "$cmd" ]] || exit 0
[[ "$cmd" == *push* ]] || exit 0

deny() {
    jq -n --arg reason "Force push blocked by block-force-push.sh ($1 in: $2). Use a normal push, or edit the hook if this is intentional." '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
}

# Words that may precede git in command position (`env git`, `sh -c "git ..."`).
is_prefix_word() {
    case "${1##*/}" in
        env | command | exec | nohup | sudo | time | nice | timeout | xargs) return 0 ;;
        sh | bash | zsh | dash | ksh) return 0 ;;
        -* | [0-9]*) return 0 ;;
    esac
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]
}

# Quotes are dropped so `sh -c "git push -f"` and `git push "+main"` tokenize
# like their unquoted forms; the command splits on shell separators so
# `git push && rm -f junk` does not false-positive.
cmd=${cmd//$'\\\n'/ }
cmd=${cmd//[\"\']/}
cmd=${cmd//[;|&()\`]/$'\n'}

while IFS= read -r segment; do
    read -ra words <<< "$segment" || true
    n=${#words[@]}
    i=0

    while [[ $i -lt $n ]] && [[ "${words[$i]##*/}" != git ]]; do
        is_prefix_word "${words[$i]}" || continue 2
        i=$((i + 1))
    done
    [[ $i -lt $n ]] || continue
    i=$((i + 1))

    # Skip git's global options to reach the subcommand.
    while [[ $i -lt $n ]] && [[ "${words[$i]}" == -* ]]; do
        case "${words[$i]}" in
            -C | -c | --git-dir | --work-tree | --namespace | --config-env) i=$((i + 2)) ;;
            *) i=$((i + 1)) ;;
        esac
    done
    [[ $i -lt $n ]] && [[ "${words[$i]}" == push ]] || continue

    for ((i = i + 1; i < n; i++)); do
        word=${words[$i]}
        case "$word" in
            --force-with-lease* | --force-if-includes*)
                [[ "$ALLOW_LEASE" -eq 1 ]] || deny "$word" "${segment# }"
                ;;
            --force | --force=*) deny "--force" "${segment# }" ;;
            --mirror) deny "--mirror" "${segment# }" ;;
            --*) ;;
            -*f*) deny "-f" "${segment# }" ;;
            +?*) deny "+refspec" "${segment# }" ;;
        esac
    done
done <<< "$cmd"

exit 0
