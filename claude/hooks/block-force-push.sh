#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: deny git force-pushes wherever the flag sits in the command.
# Permission deny rules match on command prefix only, so `Bash(git push --force:*)`
# misses `git push origin main --force`. This inspects the whole command string.
# Receives JSON on stdin with tool_name and tool_input fields.

# Set to 1 to permit --force-with-lease / --force-if-includes (the safer variants).
ALLOW_LEASE=0

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$tool_name" == "Bash" ]] || exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -n "$cmd" ]] || exit 0
[[ "$cmd" == *push* ]] || exit 0

deny() {
    jq -n --arg reason "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
}

# Split on shell separators so `git push && rm -f junk` does not false-positive
while IFS= read -r segment; do
    [[ "$segment" =~ (^|[[:space:]])git([[:space:]]|$) ]] || continue
    [[ "$segment" =~ (^|[[:space:]])push([[:space:]]|$) ]] || continue

    if [[ "$ALLOW_LEASE" -eq 1 ]] && [[ "$segment" =~ --force-(with-lease|if-includes) ]]; then
        continue
    fi

    if [[ "$segment" =~ (^|[[:space:]])--force([=[:space:]]|-[a-z-]+|$) ]]; then
        deny "Force push blocked by block-force-push.sh (--force in: ${segment# }). Use a normal push, or edit the hook if this is intentional."
    fi

    if [[ "$segment" =~ (^|[[:space:]])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$) ]]; then
        deny "Force push blocked by block-force-push.sh (-f in: ${segment# }). Use a normal push, or edit the hook if this is intentional."
    fi
done < <(echo "$cmd" | tr ';|&' '\n')

exit 0
