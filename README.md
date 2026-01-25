# dots

A collection of dotfiles to make my life at the command line easier (or harder).

Found, borrowed, stolen, picked, and pulled from peers, colleagues, blogs, forums, posts, AI, Claude, and more. Refined through daily use at home, on the job, and remotely.

Used across various platforms for various things.

---

## Features

- **Catppuccin Mocha theme** across Ghostty, fzf, and Neovim
- **Automated setup** with intelligent backup and symlink management
- **Platform-specific profiles** for macOS and Linux
- **Modern tooling** with Starship prompt, Zinit plugin manager, and NVChad
- **Vi mode** keybindings in zsh for modal editing
- **Tmux integration** with plugin management and custom layouts
- **Claude Code configuration** with custom skills and git safety hooks

## Tools & Prerequisites

**Required:**
- **[Git](https://git-scm.com/)** - Version control (required for setup and plugin management)
- **[zsh](https://www.zsh.org/)** - Shell (recommended as default shell)
- **curl** or **wget** - For downloading plugins

**macOS:**
- **[Homebrew](https://brew.sh/)** - Package manager

**Recommended:**
- **[Ghostty](https://ghostty.org/)** - Fast, feature-rich terminal emulator
- **[JetBrains Mono Nerd Font](https://www.nerdfonts.com/font-downloads)** - Nerd Font with icon support (required for prompt symbols)
- **[Starship](https://starship.rs/)** - Fast, customizable cross-shell prompt
- **[Neovim](https://neovim.io/)** - Modern vim with [NVChad](https://nvchad.com/) configuration
- **[tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with plugin support
- **[fzf](https://github.com/junegunn/fzf)** - Fuzzy finder for command history and file search
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** - Smarter cd command

**Optional:**
- **[vivid](https://github.com/sharkdp/vivid)** - LS_COLORS generator (Catppuccin theme)
- **[mosh](https://mosh.org/)** - Mobile shell for better remote connections
- **[pyenv](https://github.com/pyenv/pyenv)** - Python version manager
- **[nvm](https://github.com/nvm-sh/nvm)** - Node version manager
- **[Bun](https://bun.sh/)** - Fast JavaScript runtime and package manager
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** - AI-powered coding assistant CLI

*The setup script automatically installs [Zinit](https://github.com/zdharma-continuum/zinit) plugin manager, NVChad, and Tmux Plugin Manager.*

## Platforms

- macOS
- Linux
- iPadOS (via [Blink](https://blink.sh/))

---

## Installation

### Check Prerequisites

Run this command to check which tools are installed:

```bash
for cmd in git zsh curl wget starship nvim tmux fzf zoxide; do command -v $cmd >/dev/null && echo "✓ $cmd" || echo "✗ $cmd"; done
```

### Quick Start

```bash
git clone https://github.com/just1jray/dots.git ~/Developer/src/dots
cd ~/Developer/src/dots
./setup.sh
```

### Setup Script Options

```bash
./setup.sh [options]

Options:
  -h, --help          Show help message
  -f, --force         Force overwrite without backup
  -n, --dry-run       Preview changes without applying
  -s, --skip-plugins  Skip plugin installation
  -c, --check-nvchad  Check NVChad installation status
```

### What the Setup Script Does

1. **Creates necessary directories** for configs and plugins
2. **Backs up existing configs** (unless `--force` is used)
3. **Symlinks config files** to proper locations:
   - `~/.zshrc` → `zsh/zshrc`
   - `~/.config/starship.toml` → `starship/starship.toml`
   - `~/.config/nvim/` → `nvim/`
   - `~/.tmux.conf` → `tmux/tmux.conf`
   - `~/.vimrc` → `vim/vimrc`
   - `~/.claude/` → `claude/` (if Claude Code is installed)
4. **Installs Zinit** plugin manager for zsh
5. **Installs NVChad** for Neovim (if nvim is installed)
6. **Installs Tmux Plugin Manager** (TPM) and plugins
7. **Loads platform-specific profiles** based on OS

## Customization

### Platform-Specific Settings

The zshrc automatically loads platform-specific profiles:
- **macOS**: Sources `~/.config/zsh/profile-macos`
- **Linux**: Sources `~/.config/zsh/profile-linux`

Add platform-specific environment variables, paths, or aliases to these files.

### Starship Prompt

Edit `starship/starship.toml` to customize your prompt appearance and modules.

### Ghostty

The `ghostty/config` includes several customizations:

- **Custom GLSL shaders** - CRT effects and water distortion shaders in `ghostty/shaders/`
- **Quick terminal** - Toggle terminal with `ctrl+\`` (requires Ghostty 1.1+)
- **Split keybindings**:
  - `cmd+shift+enter` - Horizontal split
  - `cmd+opt+enter` - Vertical split
  - `cmd+d` - Close split

### NVChad

Customize Neovim by editing files in `nvim/lua/`:
- `chadrc.lua` - NVChad theme and UI settings
- `options.lua` - Vim options
- `mappings.lua` - Custom keybindings
- `plugins/` - Plugin configurations

### Claude Code

The dotfiles include Claude Code configuration in the `claude/` directory:

- **settings.json** - Claude Code settings with hooks configuration
- **hooks/** - Custom hook scripts
  - `stop-hook-git-check.sh` - Git safety hook that prevents closing sessions with uncommitted/unpushed changes
- **commands/** - Custom slash commands
  - `/review-edu` - Educational code review command
- **skills/** - Custom Claude Code skills
  - `session-start-hook/` - Skill for creating startup hooks in repositories
  - `code-review-edu/` - Thorough code review skill (triggers on "review this code", "find bugs", etc.)

The setup script automatically symlinks `~/.claude/` to the `claude/` directory in this repository.

**Note:** Claude Code will create additional directories in `~/.claude/` for session data, plans, and other runtime files. These are managed by Claude and not tracked in this dotfiles repository.

---

Open to suggestions, feedback, pull requests, forks, and/or ridicule.
