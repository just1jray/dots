#!/usr/bin/env bash
set -euo pipefail

# Stop hook: before Claude finishes, flag uncommitted or unpushed work.
# On the default branch it asks for a feature branch instead of a commit.
# Receives JSON on stdin with stop_hook_active and cwd fields.
# exit 2 + stderr feeds the message back to Claude; local refs only, no fetch.

input=$(cat)

stop_hook_active=false
dir=$PWD
if command -v jq >/dev/null 2>&1; then
    stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || printf 'false')
    dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
    dir=${dir:-$PWD}
elif [[ "$input" =~ \"stop_hook_active\"[[:space:]]*:[[:space:]]*true ]]; then
    stop_hook_active=true
fi

# Recursion guard: Claude is already continuing because of this hook.
[[ "$stop_hook_active" == "true" ]] && exit 0

[[ -d "$dir" ]] || exit 0
[[ "$(git -C "$dir" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || exit 0

branch=$(git -C "$dir" branch --show-current 2>/dev/null || true)
# Detached HEAD (rebase, bisect, checkout of a tag): nothing sensible to suggest.
[[ -n "$branch" ]] || exit 0

default_ref=$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
default_branch=${default_ref#origin/}

on_default=false
case "$branch" in
    main | master | "$default_branch") on_default=true ;;
esac

dirty=$(git -C "$dir" status --porcelain 2>/dev/null | head -n 1 || true)

# shellcheck disable=SC1083  # @{upstream} is valid git syntax
upstream=$(git -C "$dir" rev-parse --abbrev-ref @{upstream} 2>/dev/null || true)
ahead=0
if [[ -n "$upstream" ]]; then
    ahead=$(git -C "$dir" rev-list --count "@{upstream}..HEAD" 2>/dev/null || printf '0')
elif [[ -n "$default_ref" ]]; then
    ahead=$(git -C "$dir" rev-list --count "$default_ref..HEAD" 2>/dev/null || printf '0')
fi

branch_hint="git switch -c <prefix>/<short-kebab-description> (prefix feat/, fix/, chore/ or docs/), commit there, push, and open a PR with gh pr create"

if [[ "$on_default" == true ]]; then
    if [[ -n "$dirty" ]]; then
        printf '%s\n' "There are uncommitted changes on the default branch '$branch'. Never commit to $branch: create a feature branch first with $branch_hint. Only stage files relevant to the task." >&2
        exit 2
    fi
    if [[ "$ahead" -gt 0 ]]; then
        printf '%s\n' "The default branch '$branch' has $ahead local commit(s) not on ${upstream:-the remote}. Do not push to $branch: move the commits to a feature branch with $branch_hint." >&2
        exit 2
    fi
    exit 0
fi

if [[ -n "$dirty" ]]; then
    printf '%s\n' "There are uncommitted changes on branch '$branch'. Commit the files relevant to the task on this branch and push it." >&2
    exit 2
fi

if [[ "$ahead" -gt 0 ]]; then
    if [[ -n "$upstream" ]]; then
        printf '%s\n' "Branch '$branch' has $ahead commit(s) not pushed to $upstream. Push them (git push)." >&2
    else
        printf '%s\n' "Branch '$branch' has $ahead commit(s) and no upstream. Push it with git push -u origin $branch." >&2
    fi
    exit 2
fi

exit 0
