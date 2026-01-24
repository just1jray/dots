---
title: "refactor: Implement code review performance and cleanup findings"
type: refactor
date: 2026-01-24
deepened: 2026-01-24
priority: P2
estimated_startup_improvement: 500-1250ms
---

# refactor: Implement Code Review Performance and Cleanup Findings

## Enhancement Summary

**Deepened on:** 2026-01-24
**Research agents used:** security-sentinel, performance-oracle, architecture-strategist, code-simplicity-reviewer, pattern-recognition-specialist

### Key Improvements from Research
1. **Bug fix in NVM lazy-load pattern** - Original had `unset -f` in wrong location; corrected with guard flag
2. **Architecture recommendation** - Consider zinit native lazy loading instead of manual wrappers for consistency
3. **Additional optimization discovered** - Cache `eval` statements with evalcache plugin (50-100ms extra savings)
4. **Security hardening** - Add jq dependency check to hooks, consider `readonly` for NVM_DIR/PYENV_ROOT
5. **Simplified implementation** - Loop-based wrapper definition reduces code by 37%

### New Considerations Discovered
- pyenv lazy-loading may not be worth the pattern inconsistency (only 50-150ms savings)
- Docker fpath addition must happen BEFORE zinit's compinit, not after
- Alternative: Consider switching from NVM to fnm (40x faster, eliminates lazy-load need)

---

## Overview

Implement the P2 and P3 findings from the comprehensive code review to improve shell startup time by ~50-70% and remove ~150 lines of dead/redundant code.

## Problem Statement / Motivation

The code review identified several performance bottlenecks and code quality issues:

1. **Shell startup is slow** (620-1490ms estimated) due to synchronous loading of NVM (300-800ms), pyenv (50-150ms), and duplicate compinit calls (100-200ms)
2. **Dead code accumulation** - 83 lines of unused Starship palettes, commented nvim code, unused functions
3. **Missing error handling** in Claude hooks could cause silent failures
4. **Redundant code** - duplicate aliases, superseded options

## Proposed Solution

### Phase 1: Low-Risk Cleanup (P3 items)

Remove dead code and redundant configurations with minimal risk:

| Item | File | Lines | Action |
|------|------|-------|--------|
| Unused Starship palettes | `starship/starship.toml` | 208-291 | Remove frappe, latte, macchiato palettes |
| Commented nvim code | `nvim/lua/plugins/init.lua` | 16-27 | Remove commented treesitter block |
| Unused function | `zsh/zshenv` | 13-17 | Remove `append_to_path()` |
| Redundant history option | `zsh/zshrc` | 59 | Remove `hist_ignore_dups` |
| Duplicate alias | `zsh/aliases` | 90 | Change `sesh` to alias for `t` |

### Phase 2: Performance Optimizations (P2 items)

#### 2a. NVM Lazy Loading

Replace synchronous NVM loading with wrapper functions that load on first use.

**Current (`zsh/zshrc:149-151`):**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
```

**Proposed (CORRECTED based on research):**
```bash
# NVM lazy-loading: Unlike fzf/zoxide/pyenv which use eval-on-check,
# NVM is loaded via wrapper functions because it adds 300-800ms to startup.
# This pattern defers loading until first use of node/npm/nvm commands.
export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    _nvm_loaded=false

    _load_nvm() {
        [[ "$_nvm_loaded" == true ]] && return
        _nvm_loaded=true
        unset -f nvm node npm npx 2>/dev/null
        source "$NVM_DIR/nvm.sh"
        [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
    }

    # Wrapper functions trigger lazy load on first use
    nvm() { _load_nvm; nvm "$@"; }
    node() { _load_nvm; node "$@"; }
    npm() { _load_nvm; npm "$@"; }
    npx() { _load_nvm; npx "$@"; }
fi
```

### Research Insights: NVM Lazy Loading

**Best Practices (from performance-oracle):**
- Add guard flag (`_nvm_loaded`) to prevent multiple loads
- Move `unset -f` BEFORE `source`, not after function definitions (bug in original)
- Wrap entire block in file existence check

**Simplified Alternative (from code-simplicity-reviewer):**
```bash
# Minimal loop-based approach (37% fewer lines)
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    for cmd in nvm node npm npx; do
        eval "$cmd() { unset -f nvm node npm npx; source \"\$NVM_DIR/nvm.sh\"; $cmd \"\$@\"; }"
    done
fi
```

**Alternative: Switch to fnm (from performance-oracle):**
- fnm is 40x faster than NVM (~10ms vs 500ms)
- Eliminates need for lazy loading entirely
- Drop-in replacement, reads `.nvmrc` files
- Installation: `brew install fnm` then `eval "$(fnm env --use-on-cd)"`

**Security Considerations (from security-sentinel):**
- Consider `readonly NVM_DIR` after setting to prevent modification
- Validate NVM_DIR is absolute path before sourcing

**Expected improvement:** 300-800ms saved on startup

---

#### 2b. Remove Redundant compinit (CRITICAL)

The Docker Desktop completions section calls `compinit` redundantly (already handled by zinit's `zicompinit`).

**Current (`zsh/zshrc:191-196`):**
```bash
# The following lines have been added by Docker Desktop...
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
```

**Proposed (CORRECTED - fpath must be added BEFORE zinit's compinit):**

1. **Remove lines 191-196 entirely**

2. **Add Docker fpath near top of zshrc, BEFORE the zinit fast-syntax-highlighting block:**
```bash
# Docker CLI completions (fpath must be set before compinit)
# Note: Docker Desktop may re-add compinit lines - remove them if so
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
```

### Research Insights: compinit

**Best Practices (from architecture-strategist):**
- fpath modifications MUST happen before compinit is called
- zinit's `zicompinit` (line 79) is the canonical compinit call
- Docker Desktop auto-adds these lines on update - add warning comment

**Cache-based compinit optimization (from performance-oracle):**
```bash
# Only regenerate completions cache once per day
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C  # Use cache, skip security check
fi
```
Note: zinit may already do this via zicompinit.

**Expected improvement:** 100-200ms saved on startup

---

#### 2c. pyenv Lazy Loading (OPTIONAL - Reconsider)

### Research Insights: pyenv

**Architecture recommendation (from architecture-strategist):**
> "pyenv already uses Pattern A (eval-on-check); 50-150ms savings may not justify pattern inconsistency. The codebase would have THREE deferred loading strategies, increasing cognitive load."

**Performance insight (from performance-oracle):**
- pyenv shims are already in PATH via zshenv
- `pyenv init -` adds shell integration, rehash, completions
- Minimal init: `eval "$(pyenv init --path)"` only sets PATH (~5ms)

**Recommendation:** DEFER this change. Measure actual pyenv init time first:
```bash
time (pyenv init - >/dev/null)
```
If under 50ms, keep eager loading for pattern consistency.

**If proceeding, use this pattern:**
```bash
# Lazy-load pyenv (only if init time > 50ms)
if [[ -d "$PYENV_ROOT" ]]; then
    _load_pyenv() {
        unset -f pyenv python python3 pip pip3 2>/dev/null
        eval "$(pyenv init - --no-rehash)"
    }

    for cmd in pyenv python python3 pip pip3; do
        eval "$cmd() { _load_pyenv; $cmd \"\$@\"; }"
    done
fi
```

---

### Phase 3: Error Handling Improvements (P2 items)

Add strict error handling to Claude hooks.

#### 3a. `claude/hooks/stop-hook-git-check.sh`

**Proposed changes:**
```bash
#!/bin/bash
set -euo pipefail

# Validate jq is available (required for JSON parsing)
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Read the JSON input from stdin
input=$(cat)
# ... rest of script unchanged
```

### Research Insights: Strict Mode

**Security considerations (from security-sentinel):**
- Add jq availability check before parsing JSON
- The existing `|| unpushed=0` patterns handle expected failures correctly with pipefail
- All variables are properly initialized before use

**Pitfalls to avoid (from pattern-recognition-specialist):**
- `set -e` will exit on any non-zero return; ensure all expected failures use `|| true` or `|| fallback`
- `set -u` requires all variables to be set; use `${var:-default}` for optional variables
- `set -o pipefail` means any pipe component failure fails the whole pipe

#### 3b. `claude/scripts/context-bar.sh`

Add after shebang:
```bash
set -euo pipefail
```

**Note:** Variables like `$branch` and `$upstream` may be empty strings (OK with `-u`) but script handles this with default values.

---

## Additional Optimizations (from research)

### Cache eval Statements with evalcache

**From performance-oracle:** Install evalcache plugin for 50-100ms additional savings:

```bash
# Install
zinit light mroth/evalcache

# Replace eval statements:
# Before: eval "$(fzf --zsh)"
# After:  _evalcache fzf --zsh

# Before: eval "$(zoxide init --cmd cd zsh)"
# After:  _evalcache zoxide init --cmd cd zsh

# Before: eval "$(starship init zsh)"
# After:  _evalcache starship init zsh
```

Cache is automatically invalidated when the binary changes.

### OMZ Snippets Optimization

**From performance-oracle:** Consider deferring non-critical OMZ snippets:

```bash
# Currently (synchronous):
zinit snippet OMZP::docker
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl

# Optimized (deferred):
zinit wait lucid for \
    OMZP::docker \
    OMZP::aws \
    OMZP::kubectl
```

**Expected savings:** 30-90ms (if these tools aren't used immediately)

---

## Technical Considerations

### Constraints

1. **fast-syntax-highlighting must stay synchronous** - Turbo mode causes prompt rendering issues (documented in codebase)
2. **NVM is a function, not binary** - Check for `nvm.sh` file, not `command -v nvm`
3. **Docker Desktop may re-add compinit** - Add comment warning about this
4. **fpath must be modified BEFORE compinit** - Order matters for completion system

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| NVM lazy-load breaks .nvmrc auto-switch | Wrapper functions trigger on any node/npm use; manual `nvm use` still works |
| IDE integration needs node immediately | VSCode/Cursor excluded from tmux auto-start; terminal init happens before debugging |
| Removing compinit breaks completions | zicompinit already handles this; test Docker completions after change |
| Strict mode breaks Claude hooks | Added jq dependency check; reviewed all pipeline failures |
| Three lazy-load patterns creates confusion | Document NVM exception clearly; defer pyenv lazy-loading |

### Security Hardening (from security-sentinel)

| Recommendation | Priority | Implementation |
|----------------|----------|----------------|
| Add jq check to hooks | High | Add `command -v jq` check |
| Consider `readonly NVM_DIR` | Low | Prevents malicious modification |
| Validate absolute paths | Low | Check `$NVM_DIR` starts with `/` |
| Set umask 077 | Low | Secure file creation |

---

## Acceptance Criteria

### Functional Requirements

- [x] Shell startup time reduced by at least 300ms (measured with `time zsh -i -c exit`)
- [ ] `node -v`, `npm -v`, `nvm --version` work correctly after lazy-load
- [ ] `.nvmrc` auto-switching works when running any node command in project directory
- [x] `pyenv` commands work correctly (skipped lazy-load per recommendation)
- [ ] Docker tab completions work (`docker <TAB>`)
- [x] Claude hooks execute without errors in normal git repositories
- [x] Claude hooks handle edge cases (non-git directories, missing tools)
- [x] Claude hooks fail gracefully when jq is missing

### Code Quality

- [x] All shell scripts pass `shellcheck`
- [x] No dead/commented code remains
- [x] All changes documented with inline comments where behavior is non-obvious
- [x] Pattern documentation added to explain NVM lazy-load exception

---

## Success Metrics

| Metric | Before | Target |
|--------|--------|--------|
| Shell startup time | 620-1490ms | 200-400ms |
| Lines of code | ~1100 | ~950 |
| Redundant compinit calls | 2 | 1 |
| Unused functions | 1 | 0 |
| Deferred loading patterns | 3 | 2 (skip pyenv lazy-load) |

---

## Implementation Order (Revised)

1. [x] **Commit 1:** Remove unused Starship palettes (lowest risk, 83 LOC reduction)
2. [x] **Commit 2:** Remove commented nvim code and unused `append_to_path()`
3. [x] **Commit 3:** Fix redundant alias and history option
4. [x] **Commit 4:** Move Docker fpath and remove redundant compinit (test completions)
5. [x] **Commit 5:** Add strict mode + jq check to Claude hooks
6. [x] **Commit 6:** Implement NVM lazy loading with guard flag (highest impact)
7. [ ] **Commit 7 (OPTIONAL):** Implement pyenv lazy loading - SKIPPED per recommendation
8. [ ] **Commit 8 (OPTIONAL):** Add evalcache for additional optimizations - SKIPPED per user choice

---

## Testing Checklist

### Before Changes (Baseline)
```bash
# Measure current startup time (run 5x for accuracy)
hyperfine --warmup 3 --shell=none "zsh -i -c exit"
# Or manual:
for i in {1..5}; do time zsh -i -c exit; done

# Profile with zprof (add to top/bottom of zshrc)
ZSH_DEBUGRC=1 zsh -i -c exit

# Verify current functionality
node -v && npm -v && nvm --version
python --version && pyenv --version
docker completion  # Tab complete test

# Measure pyenv init time (to decide on lazy-loading)
time (pyenv init - >/dev/null)
```

### After Each Phase

**Phase 1 (Cleanup):**
- [ ] Shell starts without errors
- [ ] Starship prompt renders correctly
- [ ] Nvim launches without errors

**Phase 2 (Performance):**
- [ ] Startup time improved by target amount
- [ ] `node -v` works (triggers lazy load)
- [ ] `npm install` works in a project
- [ ] `nvm use 18` switches versions
- [ ] `docker <TAB>` shows completions
- [ ] `python --version` works
- [ ] `pyenv versions` lists installed versions

**Phase 3 (Error Handling):**
- [ ] Hooks work in git repository with changes
- [ ] Hooks work in git repository without changes
- [ ] Hooks exit gracefully in non-git directory
- [ ] Hooks show clear error when jq is missing

---

## References & Research

### Internal References

- Code review findings: This session's comprehensive analysis
- Zinit turbo mode pattern: `zsh/zshrc:83-87`
- Error handling pattern: `zsh/zshrc:97-114` (fzf initialization)
- Shellcheck config: `.shellcheckrc`

### External References

- [Improve zsh startup time via lazyload](https://sumercip.com/posts/lazyload-zsh/)
- [Fix slow ZSH startup due to NVM](https://dev.to/thraizz/fix-slow-zsh-startup-due-to-nvm-408k)
- [Achieving 30ms Zsh Startup](https://dev.to/tmlr/achieving-30ms-zsh-startup-40n1)
- [Zinit documentation](https://github.com/zdharma-continuum/zinit)
- [evalcache plugin](https://github.com/mroth/evalcache)
- [fnm - Fast Node Manager](https://github.com/Schniz/fnm) (40x faster than NVM)
- [zsh-defer](https://github.com/romkatv/zsh-defer) (lighter than zinit turbo)

### Related Files

| File | Changes |
|------|---------|
| `zsh/zshrc` | NVM lazy-load, Docker fpath move, remove compinit |
| `zsh/zshenv` | Remove `append_to_path()` |
| `zsh/aliases` | Change `sesh` to alias `t` |
| `starship/starship.toml` | Remove unused palettes |
| `nvim/lua/plugins/init.lua` | Remove commented code |
| `claude/hooks/stop-hook-git-check.sh` | Add strict mode + jq check |
| `claude/scripts/context-bar.sh` | Add strict mode |
