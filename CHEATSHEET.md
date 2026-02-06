# Cheatsheet

Quick reference for this dotfiles setup. Emphasis on Vim/Neovim, tmux, git, and shell workflows.

---

## Zsh

### Modes & keybinds

| Key | Does | Notes |
| --- | --- | --- |
| `Esc` | Normal mode | Vi mode is enabled. |
| `Ctrl-p` | History search backward | Searches previous commands. |
| `Ctrl-n` | History search forward | Searches next commands. |
| `Alt-w` | `kill-region` | Only works if a region is selected. See below. |
| `Esc Esc` | Toggle `sudo` | From OMZP::sudo. Uses `sudo -e` for editor commands. |

**Kill region**
- Select text on the command line, then press `Alt-w` to delete it.
- Steps: set a mark (`Ctrl-Space` or `Ctrl-@`), move cursor to select, then `Alt-w`.

### Shell aliases (custom)

| Alias | Expands to | Purpose |
| --- | --- | --- |
| `zfig` | `$EDITOR ~/.zshrc` | Edit zshrc. |
| `zfresh` | `source ~/.zshenv && source ~/.zshrc` | Reload zsh config. |
| `efresh` | function | Reload zsh + tmux config. |
| `dev` | `cd ~/Developer && ls -lah` | Jump + list. |
| `src` | `cd ~/Developer/src && ls -lah` | Jump + list. |
| `dots` | `cd ~/Developer/src/dots && ls -lah` | Jump + list. |
| `docs` | `cd ~/Documents` | Jump. |
| `dl` | `cd ~/Downloads` | Jump. |
| `dt` | `cd ~/Desktop` | Jump. |
| `..` / `...` / `....` | `cd ..` etc | Quick up navigation. |
| `-` | `cd -` | Back to previous directory. |
| `ll` | `ls -lah` | List. |
| `la` | `ls -la` | List. |
| `c` | `clear` | Clear screen. |
| `path` | show `$PATH` entries | One per line. |
| `myip` | `curl -s ifconfig.me` | External IP. |
| `activate` | `source ./venv/bin/activate` | Python venv. |
| `mkvenv` | function | Create venv if missing. |

### Tmux helpers (shell)

| Alias | Does |
| --- | --- |
| `t` / `sesh` | Attach or create tmux session named `sesh`. |
| `treset` | Rebuild the `sesh` session (optional `-c` clears resurrect state). |
| `tfresh` | Reload `~/.tmux.conf`. |

---

## Git

### Mental model (quick)

| Term | Meaning |
| --- | --- |
| Working tree | Files on disk (what you’re editing). |
| Staging area | What’s queued for the next commit. |
| Commit | A snapshot of staged changes. |
| Remote | Another copy of the repo (e.g., GitHub). |

### Core aliases (from `git/gitconfig`)
Use as `git <alias>`.

| Alias | Expands to | Purpose |
| --- | --- | --- |
| `st` | `status -sb` | Short status. |
| `co` | `checkout` | Checkout branch/file. |
| `cob` | `checkout -b` | Create branch. |
| `br` | `branch` | List branches. |
| `ci` | `commit` | Commit. |
| `cm` | `commit -m` | Commit with message. |
| `df` | `diff` | Working tree diff. |
| `dfc` | `diff --cached` | Staged diff. |
| `lg` | `log --oneline --graph --decorate` | Compact history graph. |
| `last` | `log -1 HEAD --stat` | Last commit details. |

### Daily commands

| Task | Command |
| --- | --- |
| Check status | `git st` |
| Stage all | `git add -A` |
| Stage interactively | `git add -p` |
| Commit | `git ci` or `git cm "message"` |
| Push | `git push` |
| Pull | `git pull` |
| View changes | `git df` / `git dfc` |
| View history | `git lg` / `git last` |

### Branching & sync

| Task | Command |
| --- | --- |
| New branch | `git cob feature/name` |
| Switch branch | `git co branch-name` |
| List branches | `git br` |
| Delete branch | `git branch -d name` (safe) / `-D` (force) |
| Fetch + prune | `git fetch` (your config prunes branches/tags) |
| Compare to upstream | `git log --oneline --decorate --graph --left-right --count HEAD...@{upstream}` |

### Undo & fix mistakes

| Situation | Command |
| --- | --- |
| Unstage a file | `git restore --staged <file>` |
| Discard local changes | `git restore <file>` |
| Amend last commit | `git commit --amend` |
| Undo last commit, keep changes | `git reset --mixed HEAD~1` |
| Revert a pushed commit | `git revert <sha>` |

**Tip**: Use `git st` and `git df` often to stay oriented.

---

## Neovim / Vim

### Your config basics

| Item | Value |
| --- | --- |
| Leader key | `Space` |
| Enter command-line | `;` |
| Exit insert | `jk` |
| Theme | Catppuccin (NVChad) |
| Plugin manager | `lazy.nvim` |

### NVChad specifics (from your config)

| Feature | Enabled | Where |
| --- | --- | --- |
| LSP servers | `html`, `cssls` | `nvim/lua/configs/lspconfig.lua` |
| Formatter | `stylua` for Lua | `nvim/lua/configs/conform.lua` |
| Plugins | minimal custom set | `nvim/lua/plugins/init.lua` |

### NVChad discovery (what’s actually installed)

| Item | What it is | How to check |
| --- | --- | --- |
| LSP | Language server support (completion, go-to, diagnostics) | `:LspInfo` |
| Treesitter | Better parsing + syntax highlighting | `:Lazy` → search `treesitter` |
| Telescope | Fuzzy finder UI | `:Lazy` → search `telescope` or try `:Telescope` |
| Mason | LSP/DAP/formatter manager | `:Lazy` → search `mason` |

### Helpful Neovim commands

| Command | Purpose |
| --- | --- |
| `:Lazy` | Plugin manager UI. |
| `:LspInfo` | See active LSP servers for the buffer. |
| `:checkhealth` | Diagnose common issues. |
| `:messages` | View recent errors/messages. |

### NVChad plugins (install & list)

| Task | How |
| --- | --- |
| List plugins | Run `:Lazy` and browse the list. |
| Install a plugin | Add it to your plugin spec file, then run `:Lazy sync`. |
| Update plugins | `:Lazy update` |
| Remove plugins | Delete from spec, then `:Lazy clean` |

**Where to add plugins**\n\nIn this repo, plugin specs live in `nvim/lua/plugins/init.lua`. On other NVChad setups, the file may be different, but the flow is the same: edit the plugin spec, then run `:Lazy sync`.\n
### Telescope (if installed)

| Command | Purpose |
| --- | --- |
| `:Telescope find_files` | Fuzzy find files. |
| `:Telescope live_grep` | Search text in project. |
| `:Telescope buffers` | Switch buffers. |
| `:Telescope help_tags` | Search help docs. |

### Treesitter (if installed)

| Command | Purpose |
| --- | --- |
| `:TSInstall <lang>` | Install parser for a language. |
| `:TSUpdate` | Update all parsers. |
| `:TSModuleInfo` | Inspect Treesitter modules. |

### Core movement (Normal mode)

| Keys | Moves |
| --- | --- |
| `h j k l` | left / down / up / right |
| `w` / `b` | next / previous word |
| `e` | end of word |
| `0` / `^` / `$` | start / first non-blank / end of line |
| `gg` / `G` | top / bottom of file |
| `{` / `}` | previous / next paragraph |
| `f<char>` / `F<char>` | find next/prev char on line |
| `t<char>` / `T<char>` | to before next/prev char |
| `;` / `,` | repeat / reverse last `f/t` search |

### Editing basics

| Keys | Action |
| --- | --- |
| `i` / `a` | insert / append |
| `o` / `O` | new line below / above |
| `x` | delete character |
| `dd` | delete line |
| `yy` | yank line |
| `p` / `P` | paste after / before |
| `u` / `Ctrl-r` | undo / redo |
| `.` | repeat last change |

### Text objects (powerful)

| Keys | Action |
| --- | --- |
| `diw` | delete inner word |
| `ciw` | change inner word |
| `di"` | delete inside quotes |
| `ci(` | change inside parentheses |

### Search / replace

| Keys | Action |
| --- | --- |
| `/` / `?` | search forward / backward |
| `n` / `N` | next / previous match |
| `:%s/old/new/g` | replace in file |
| `:nohl` | clear search highlight |

### Windows & splits

| Command | Action |
| --- | --- |
| `:sp` / `:vsp` | horizontal / vertical split |
| `Ctrl-w h/j/k/l` | move between splits |
| `:q` / `:wq` | quit / save + quit |

### Neovim glossary (common terms)

| Term | What it is | Why it matters |
| --- | --- | --- |
| LSP | Language Server Protocol | Code intelligence: completion, go-to, diagnostics. |
| Treesitter | Parser-based syntax engine | Better highlighting and text objects. |
| Telescope | Fuzzy finder UI | Fast file/buffer/grep navigation. |

---

## Tmux

### Prefix
- Prefix is **`Ctrl-a`**.

### Pane & window movement

| Keys | Action |
| --- | --- |
| `Prefix + h/j/k/l` | move between panes |
| `Alt + arrows` | move panes (no prefix) |
| `Shift + arrows` | move windows (no prefix) |
| `Alt + h/l` | move windows |

### Splits

| Keys | Action |
| --- | --- |
| `Prefix + "` | horizontal split |
| `Prefix + %` | vertical split |

### Copy mode (vi)

| Keys | Action |
| --- | --- |
| `Prefix + [` | enter copy mode |
| `v` | start selection |
| `Ctrl-v` | block selection |
| `y` | copy and exit |

### Session save/restore

| Keys | Action |
| --- | --- |
| `Prefix + S` | save session (resurrect) |
| `Prefix + R` | restore session |

### Plugins in use
- `tmux-resurrect`, `tmux-continuum`, `tmux-yank`, `vim-tmux-navigator`, `catppuccin/tmux`.

---

## Starship prompt

| Item | Value |
| --- | --- |
| Theme | Catppuccin Mocha |
| Git status | enabled by Starship (no OMZ git) |
| Config file | `starship/starship.toml` |

---

## Tooling quick hits

### Node / npm / nvm

| Item | Behavior |
| --- | --- |
| nvm | Lazy-loaded on first use of `node`/`npm`/`npx`/`nvm` |
| Node | Available after nvm load |

### Bun

| Item | Behavior |
| --- | --- |
| Completions | Auto-loaded from `~/.bun/_bun` if present |

### Pyenv

| Item | Behavior |
| --- | --- |
| Init | Runs if `pyenv` exists |

### fzf + fzf-tab

| Item | Behavior |
| --- | --- |
| fzf | Auto-init when installed |
| fzf-tab | Enabled, with previews for `cd` / zoxide |

### zoxide

| Item | Behavior |
| --- | --- |
| `cd` | Enhanced jumping based on history |

---

## Ghostty

| Item | Notes |
| --- | --- |
| Config | `ghostty/config` |
| Shaders | `ghostty/shaders/*.glsl` |
| Quick terminal | Toggle with `ctrl+\`` (requires Ghostty 1.1+) |
| Splits | `cmd+shift+enter` (horizontal), `cmd+opt+enter` (vertical) |
| Close split | `cmd+d` |

---

## Claude Code

| Item | Location |
| --- | --- |
| Settings | `claude/settings.json` |
| Hooks | `claude/hooks/` |
| Skills | `claude/skills/` |
| Status line | `claude/scripts/context-bar.sh` |

---

## Setup / maintenance

| Task | Command |
| --- | --- |
| Install | `./setup.sh` |
| Dry run | `./setup.sh --dry-run` |
| Check NVChad | `./setup.sh --check-nvchad` |
| Reload zsh | `zfresh` or `efresh` |
| Reload tmux | `tfresh` |
