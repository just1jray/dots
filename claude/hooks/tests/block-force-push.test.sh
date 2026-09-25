#!/usr/bin/env bash
set -euo pipefail

# Feeds commands through block-force-push.sh and asserts allow/deny.
# Run: bash claude/hooks/tests/block-force-push.test.sh

hook="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/block-force-push.sh"
bash_bin=${BASH:-/bin/bash}
pass=0
fail=0

# Prints "deny" or "allow" for a raw stdin payload, with an optional PATH override.
verdict() {
    local payload=$1 path=${2:-$PATH} out rc=0
    out=$(printf '%s' "$payload" | PATH="$path" "$bash_bin" "$hook" 2>&1) || rc=$?
    if [[ $rc -eq 2 ]] || [[ "$out" == *'"permissionDecision": "deny"'* ]]; then
        printf 'deny'
    elif [[ $rc -eq 0 ]]; then
        printf 'allow'
    else
        printf 'error(%s)' "$rc"
    fi
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

bash_payload() {
    jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'
}

run() {
    check "$1" "$2" "$(verdict "$(bash_payload "$2")")"
}

run deny 'git push -f'
run deny 'git push --force'
run deny 'git push origin main --force'
run deny 'git push -uf origin main'
run deny 'git push -fu origin main'
run deny 'git push --force=true'
run deny 'git -C dir push -f'
run deny 'git -c k=v push -f'
run deny 'GIT_TRACE=1 git push -f'
run deny 'command git push -f'
run deny 'env git push -f'
run deny $'git status\ngit push -f'
run deny 'git push -f&&echo done'
run deny 'git push --force-with-lease'
run deny 'git push --force-if-includes'
run deny 'git push origin +main'
run deny 'git push origin +HEAD:main'
run deny 'git push "+main"'
run deny 'git push --mirror'
run deny '/usr/bin/git push -f'
run deny 'sh -c "git push -f"'
run deny "bash -c 'git push --force'"
run deny 'git push "-f"'
run deny "git push '--force'"
run deny $'git push \\\n  --force'
run deny 'echo hi; git push origin main -f'

run allow 'git push'
run allow 'git push origin main'
run allow 'git push -u origin feat/x'
run allow 'git push && rm -f junk'
run allow 'git log --grep push -f'
run allow 'git stash push -f'
run allow 'git commit -m "make push work with -f flag"'
run allow 'echo git push -f'
run allow 'ls -la'
run allow 'git fetch --force'

check allow 'non-Bash tool' "$(verdict '{"tool_name":"Edit","tool_input":{"file_path":"x"}}')"
check allow 'empty command' "$(verdict '{"tool_name":"Bash","tool_input":{}}')"

# Fail-closed paths: invalid JSON, and jq missing from PATH.
check deny 'invalid JSON with force push' "$(verdict '{not json git push -f')"
check allow 'invalid JSON without push' "$(verdict '{not json ls -la')"

nojq=$(mktemp -d)
trap 'rm -rf "$nojq"' EXIT
ln -s "$(command -v cat)" "$nojq/cat"
check deny 'no jq: git push -f' "$(verdict "$(bash_payload 'git push -f')" "$nojq")"
check deny 'no jq: git push origin +main' "$(verdict "$(bash_payload 'git push origin +main')" "$nojq")"
check allow 'no jq: git status' "$(verdict "$(bash_payload 'git status')" "$nojq")"
check allow 'no jq: git push origin main' "$(verdict "$(bash_payload 'git push origin main')" "$nojq")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
