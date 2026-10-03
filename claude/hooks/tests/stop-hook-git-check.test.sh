#!/usr/bin/env bash
set -euo pipefail

# Builds throwaway repos, runs stop-hook-git-check.sh against them, and asserts block/allow.
# Run: bash claude/hooks/tests/stop-hook-git-check.test.sh

hook="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stop-hook-git-check.sh"
bash_bin=${BASH:-/bin/bash}
pass=0
fail=0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# Prints "block" or "allow" for the hook run with cwd set to $1.
verdict() {
    local dir=$1 active=${2:-false} rc=0
    jq -n --arg d "$dir" --argjson a "$active" '{cwd: $d, stop_hook_active: $a}' \
        | "$bash_bin" "$hook" >/dev/null 2>&1 || rc=$?
    case $rc in
        0) printf 'allow' ;;
        2) printf 'block' ;;
        *) printf 'error(%s)' "$rc" ;;
    esac
}

check() {
    local expected=$1 label=$2 got=$3
    if [[ "$got" == "$expected" ]]; then
        pass=$((pass + 1))
        printf 'ok    %-5s %s\n' "$got" "$label"
    else
        fail=$((fail + 1))
        printf 'FAIL  %-5s %s (expected %s)\n' "$got" "$label" "$expected"
    fi
}

# Fresh repo on main with a few committed files; prints its path.
new_repo() {
    local repo
    repo=$(mktemp -d "$tmp/repo.XXXXXX")
    git -C "$repo" init -q -b main
    mkdir -p "$repo/ghostty" "$repo/opencode" "$repo/zsh"
    printf 'a\n' >"$repo/ghostty/config"
    printf 'a\n' >"$repo/opencode/opencode.json"
    printf 'a\n' >"$repo/zsh/zshrc"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m init
    printf '%s' "$repo"
}

# Commits a shared ignore file with the given lines.
shared_ignore() {
    local repo=$1
    shift
    printf '%s\n' "$@" >"$repo/.claude-stop-hook-ignore"
    git -C "$repo" add .claude-stop-hook-ignore
    git -C "$repo" commit -q -m ignore
}

r=$(new_repo)
check allow 'clean repo' "$(verdict "$r")"
printf 'b\n' >>"$r/ghostty/config"
check block 'dirty tracked file, no ignore file' "$(verdict "$r")"
check allow 'stop_hook_active short-circuits' "$(verdict "$r" true)"

r=$(new_repo)
shared_ignore "$r" '# machine-local settings' '' 'ghostty/config' 'opencode/opencode.json'
printf 'b\n' >>"$r/ghostty/config"
printf 'b\n' >>"$r/opencode/opencode.json"
check allow 'shared ignore covers every dirty path' "$(verdict "$r")"
mkdir -p "$r/zsh/sub"
check allow 'cwd in a subdirectory, paths stay root-relative' "$(verdict "$r/zsh/sub")"
printf 'b\n' >>"$r/zsh/zshrc"
check block 'one ignored, one real change' "$(verdict "$r")"

r=$(new_repo)
printf 'zsh/zshrc\n' >"$r/.git/info/stop-hook-ignore"
printf 'b\n' >>"$r/zsh/zshrc"
check allow 'clone-local ignore in .git/info' "$(verdict "$r")"
printf 'b\n' >>"$r/ghostty/config"
check block 'clone-local ignore does not cover other paths' "$(verdict "$r")"

r=$(new_repo)
shared_ignore "$r" 'ghostty/*'
printf 'b\n' >>"$r/ghostty/config"
printf 'new\n' >"$r/ghostty/untracked"
check allow 'glob pattern covers tracked and untracked files' "$(verdict "$r")"

r=$(new_repo)
printf 'ghostty/config\n' >"$r/.claude-stop-hook-ignore"
printf 'b\n' >>"$r/ghostty/config"
check block 'uncommitted shared ignore file is itself a change' "$(verdict "$r")"

r=$(new_repo)
shared_ignore "$r" 'ghostty/config'
git -C "$r" switch -q -c fix/thing
printf 'b\n' >>"$r/ghostty/config"
check allow 'feature branch with only ignored changes' "$(verdict "$r")"
printf 'b\n' >>"$r/zsh/zshrc"
check block 'feature branch with a real change' "$(verdict "$r")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
