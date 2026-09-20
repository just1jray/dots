# dots ⚫️🔵🔴⚪️

[![ShellCheck](https://github.com/just1jray/dots/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/just1jray/dots/actions/workflows/shellcheck.yml)

A collection of dotfiles to make my life at the command line easier (or harder).

Found, borrowed, stolen, picked, and pulled from peers, colleagues, blogs, forums, posts, AI, Claude, and more. Refined through daily use at home, on the job, and remotely.

Used across various platforms for various things.

---

## ✨ Features

- 🎨 **Catppuccin Mocha theme** across Ghostty, Starship, fzf, and Neovim on every OS
- ⚙️ **Automated setup** with intelligent backup and symlink management
- 💻 **Platform-specific profiles** for macOS and Linux
- 🚀 **Modern tooling** with Starship prompt, Zinit plugin manager, and NVChad
- ⌨️ **Vi mode** keybindings in zsh for modal editing
- 🪟 **Tmux integration** with plugin management and custom layouts
- 🤖 **Claude Code configuration** with custom skills and git safety hooks

## 🔧 Tools & Prerequisites

**Required:**
- 🔗 **[Git](https://git-scm.com/)** - Version control (required for setup and plugin management)
- 🐚 **[zsh](https://www.zsh.org/)** - Shell (recommended as default shell)
- 📥 **curl** or **wget** - For downloading plugins

**🍎 macOS:**
- 🍺 **[Homebrew](https://brew.sh/)** - Package manager for Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`). The curated `Brewfile` installs daily-driver apps via `./setup.sh --brew` or `brew bundle`. Profile setup itself only installs zsh, git, and Starship (plus Neovim, tmux, and a font for `full`).

**Recommended:**
- 👻 **[Ghostty](https://ghostty.org/)** - Fast, feature-rich terminal emulator
- 🔤 **[JetBrains Mono Nerd Font](https://www.nerdfonts.com/font-downloads)** - Nerd Font with icon support (required for prompt symbols)
- 🌟 **[Starship](https://starship.rs/)** - Fast, customizable cross-shell prompt
- 📝 **[Neovim](https://neovim.io/)** - Modern vim with [NVChad](https://nvchad.com/) configuration
- 🪟 **[tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with plugin support
- 🔍 **[fzf](https://github.com/junegunn/fzf)** - Fuzzy finder for command history and file search
- 📂 **[zoxide](https://github.com/ajeetdsouza/zoxide)** - Smarter cd command

**Optional:**
- 🎨 **[vivid](https://github.com/sharkdp/vivid)** - LS_COLORS generator (Catppuccin theme)
- 📡 **[mosh](https://mosh.org/)** - Mobile shell for better remote connections
- 🐍 **[pyenv](https://github.com/pyenv/pyenv)** - Python version manager
- 📦 **[nvm](https://github.com/nvm-sh/nvm)** - Node version manager
- 🥟 **[Bun](https://bun.sh/)** - Fast JavaScript runtime and package manager
- 🤖 **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** - AI-powered coding assistant CLI
- 🖱️ **[Cursor CLI](https://cursor.com/docs/cli/overview)** - Agent CLI. Portable preferences live in `cursor/cli-config.json` and are merged into `~/.cursor/cli-config.json` (`jq` required)

*The setup script installs [Zinit](https://github.com/zdharma-continuum/zinit) (shallow clone) for the `minimal` profile. NVChad and Tmux Plugin Manager run only for `full`. `nvim/lazy-lock.json` is gitignored on purpose: Neovim plugin versions drift per machine.*

## 🖥️ Platforms

- 🍎 macOS (Apple Silicon and Intel)
- 🐧 Linux, including Raspberry Pi and Linux VMs or containers

`./setup.sh` uses Homebrew on macOS and apt on Linux when `apt-get` is present. If apt is not the manager, setup says so and does not guess. Linuxbrew is used only with `--brew`. There is no Windows or WSL-specific path, and no iPadOS/Blink profile.

---

## 📦 Installation

### ✅ Check Prerequisites

Run this command to check which tools are installed:

```bash
for cmd in git zsh curl wget starship nvim tmux fzf zoxide; do command -v $cmd >/dev/null && echo "✓ $cmd" || echo "✗ $cmd"; done
```

### 🚀 Quick Start

```bash
git clone https://github.com/just1jray/dots.git ~/Developer/src/dots
cd ~/Developer/src/dots
./setup.sh
```

`~/Developer/src/dots` is only the default location. Any clone path works: `./setup.sh` links the directory you are in, and `./update.sh` uses the clone that contains the script.

### 🎛️ Setup Script Options

```bash
./setup.sh [options]

Options:
  -h, --help              Show help message
  -f, --force             Force overwrite without backup
  -n, --dry-run           Preview changes without applying
  -s, --skip-plugins      Skip plugin installation
  -c, --check-nvchad      Check NVChad installation status
  -i, --install-font      Install JetBrains Mono Nerd Font
  -y, --yes               Continue when commands are missing (no prompt)
  -b, --brew              Install the Brewfile with Homebrew. On Linux this chooses Linuxbrew
  -p, --profile <name>    Install a specific profile (repeatable, stackable)

Profiles:
  minimal   Shell essentials: zsh, starship, git, ghostty (default)
  ai        AI tools: Claude Code config, llm skills/commands, Cursor CLI
  full      Everything: minimal plus vim, tmux, Neovim, opencode, and a Nerd Font

`minimal` installs zsh, git, and Starship. `full` also installs Neovim, tmux, and JetBrains Mono Nerd Font. pyenv, nvm, Bun, Claude, and Ghostty stay optional. macOS uses Homebrew (Apple Silicon or Intel). Linux uses apt (as root, or through `sudo`; a non-terminal run needs passwordless `sudo`), or Linuxbrew only when `--brew` is passed. Starship is not in Debian or Ubuntu repositories, so setup installs it with the official installer into `~/.local/bin`.

Setup exits `1` when a required profile package could not be installed on any OS (a failed `brew install`, a failed `apt-get install`, or a failed fallback installer). Every other step still runs first. A missing package manager is only a warning; install it and re-run.
```

### 🔄 Update

From the clone, in any directory:

```bash
./update.sh
```

`./update.sh`:

1. `git pull --ff-only` in the clone that contains the script
2. Recreates missing symlinks and relinks links that point into this or
   another `dots` checkout (a directory containing `setup.sh` and
   `zsh/zshrc`, including clones made before this command existed).
   Existing files and unrelated symlinks, including ambiguous dangling
   links, are left alone and reported.
3. Refreshes only the plugin managers the active profile uses

Update removes a symlink only when it is dangling *and* points into a `dots`
checkout at a path this repo used to ship (for example a command deleted from
`llm/commands`). A link that still resolves is never removed, even if this
clone no longer has the file; it is reported instead.

| Profile | Plugin managers |
| --- | --- |
| `minimal` | Zinit |
| `full` | Zinit, TPM, and Neovim (Lazy) |
| `claude` | none |

`minimal` does not refresh TPM or Neovim. The script never reads from the terminal, so a non-TTY run cannot hang on a prompt. If no profile is linked yet, update assumes `minimal` (the setup default).

```bash
./update.sh --dry-run
./update.sh --profile full
```

Exit status is `0` only when every step succeeded. A failed `git pull`, plugin
refresh, or relink is reported at the end and exits `1`, but the remaining
steps still run. `--dry-run` exits `1` when it finds a relink the real run
could not perform.

The `dots` shortcut jumps to the linked clone. It uses `~/Developer/src/dots` only when that clone cannot be detected. Override it with `DOTS_DIR`.

### 📋 What the Setup Script Does

0. 📦 **Installs profile packages**. `minimal`: zsh, git, Starship. `full`: also Neovim, tmux, and a Nerd Font. macOS uses Homebrew. Linux uses apt, or Linuxbrew only with `--brew`.
1. 🍺 **Installs Homebrew packages** from `Brewfile` (only with `--brew`)
2. 📁 **Creates necessary directories** for configs and plugins
3. 💾 **Backs up existing configs** (unless `--force` is used)
4. 🔗 **Symlinks config files** to proper locations:
   - `~/.zshrc` → `zsh/zshrc`
   - `~/.config/starship.toml` → `starship/starship.toml`
   - `~/.config/nvim/` → `nvim/`
   - `~/.tmux.conf` → `tmux/tmux.conf`
   - `~/.vimrc` → `vim/vimrc`
   - `~/.claude/hooks` → `claude/hooks`
   - `~/.claude/scripts` → `claude/scripts`
   - `~/.claude/CLAUDE.md` → `claude/CLAUDE.md`
   - `~/.claude/skills/*` → `llm/skills/*` (individual skill symlinks)
   - `~/.claude/commands/*` → `llm/commands/*` (individual command symlinks)
5. 🔀 **Merges Cursor CLI preferences** from `cursor/cli-config.json` into `~/.cursor/cli-config.json` (`ai` and `full` profiles). Tracked keys win; auth, cache, and other machine state already in the live file are kept. Not a symlink, because Cursor rewrites that file. Requires `jq`.
6. 🔌 **Installs Zinit** plugin manager for zsh (shallow clone, on first shell launch)
7. 📝 **Installs NVChad** for Neovim only when the `full` profile is active
8. 🪟 **Installs Tmux Plugin Manager** (TPM) and plugins only for `full` (not the unused tmux-battery clone)
9. 💻 **Loads platform-specific profiles** based on OS

## 🛠️ Customization

### 💻 Platform-Specific Settings

The zshrc automatically loads platform-specific profiles:
- 🍎 **macOS**: Sources `~/.config/zsh/profile-macos` and initializes Homebrew (`brew shellenv`) for Apple Silicon or Intel
- 🐧 **Linux**: Sources `~/.config/zsh/profile-linux`. Starship stays on Catppuccin Mocha. Linuxbrew is loaded only after `./setup.sh --brew`

Work tools in `zsh/profile-work` (GAM, Tailscale Jamf) are not sourced on every machine. Opt in from the gitignored host file `~/.config/zsh/hosts`:

```bash
export DOTS_LOAD_WORK=1
```

### 🌟 Starship Prompt

Edit `starship/starship.toml` to customize your prompt. The palette is Catppuccin Mocha on macOS and Linux. `STARSHIP_CONFIG` points at `~/.config/starship.toml` and is not unset on Linux.

### 👻 Ghostty

The `ghostty/config` theme is Catppuccin Mocha on every OS. macOS-only keys (`macos-titlebar-style`, blur, and `cmd` chords) live in `ghostty/macos` and are linked only on Darwin, so a Linux Ghostty still starts with the Mocha theme.

Setup applies its normal backup rules to both `~/.config/ghostty` and the
macOS app config before linking: regular files get a timestamped `.old_*`
copy, directories get a timestamped `.backup_*` copy, and existing symlinks
are replaced without a backup. `--force` removes regular files or directories
instead of backing them up.

- ⚡ **Quick terminal** - Toggle terminal with `ctrl+`` ` (requires Ghostty 1.1+, macOS global bind)
- ✂️ **macOS split keybindings** (`ghostty/macos`):
  - `cmd+shift+enter` - Horizontal split
  - `cmd+opt+enter` - Vertical split
  - `cmd+d` - Close split

### 📝 NVChad

Customize Neovim by editing files in `nvim/lua/`. Plugin versions are per machine: `nvim/lazy-lock.json` is gitignored so updates are not pinned to one lockfile.
- `chadrc.lua` - NVChad theme and UI settings
- `options.lua` - Vim options
- `mappings.lua` - Custom keybindings
- `plugins/` - Plugin configurations

### 🤖 Claude Code

The dotfiles include Claude Code configuration split between `claude/` (portable config) and `llm/` (skills/commands):

- 🪝 **claude/hooks/** - Custom hook scripts
  - `stop-hook-git-check.sh` - Git safety hook that prevents closing sessions with uncommitted/unpushed changes
- 📜 **claude/scripts/** - Helper scripts (e.g., `context-bar.sh`)
- 💬 **llm/commands/** - Custom slash commands
  - `/review-edu` - Educational code review command
- 🧠 **llm/skills/** - Custom Claude Code skills
  - `session-start-hook/` - Skill for creating startup hooks in repositories
  - `code-review-edu/` - Thorough code review skill (triggers on "review this code", "find bugs", etc.)

The setup script creates `~/.claude/` as a directory and symlinks individual items into it. This allows Claude's ephemeral runtime data to coexist with your dotfiles config, and enables externally installed skills/commands to live alongside repo-managed ones.

**Note:** Claude Code will create additional files in `~/.claude/` for session data, plans, and other runtime state. These are managed by Claude and not tracked in this dotfiles repository.

### 🖱️ Cursor CLI

`cursor/cli-config.json` tracks portable Cursor CLI preferences, including `approvalMode` set to `auto-review`, plus editor, display, notifications, sandbox, attribution, and a `statusLine` that reuses Claude Code's `~/.claude/scripts/context-bar.sh`. The setup script merges that file into `~/.cursor/cli-config.json` with `jq` (tracked keys win). Authentication, caches, and timestamps stay only in the live file and are not stored in this repo.

The command allowlist (`permissions`) is deliberately **not** tracked. It is a shallow merge, so tracking it would wipe any commands allowlisted interactively in Cursor on the next setup run.

---

Open to suggestions, feedback, pull requests, forks, and/or ridicule.
