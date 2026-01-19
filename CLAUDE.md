# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for macOS and Linux systems. Configuration is applied via `./setup.sh` which creates symlinks from standard config locations to files in this repo.

## Key Commands

```bash
# Run setup (backs up existing configs, creates symlinks, installs plugins)
./setup.sh

# Preview changes without applying
./setup.sh --dry-run

# Force overwrite without backup
./setup.sh --force

# Skip plugin installation
./setup.sh --skip-plugins

# Check NVChad installation status
./setup.sh --check-nvchad

# Lint shell scripts
shellcheck setup.sh zsh/* claude/hooks/*.sh
```

## Shell Script Standards

- Use `set -euo pipefail` for strict error handling
- Follow shellcheck rules configured in `.shellcheckrc`
- Target both bash and zsh compatibility where appropriate
- See `.shellcheckrc` for disabled warnings (SC1090, SC1091, SC2148, SC2312)

## Structure

- `zsh/` - Shell configuration with Zinit plugin management
- `nvim/` - NVChad-based Neovim config (lazy.nvim plugins in `lua/plugins/`)
- `claude/` - Claude Code settings, hooks, and skills
- `tmux/` - Tmux configuration with TPM plugin management
- `starship/` - Starship prompt configuration
- `ghostty/` - Ghostty terminal config (macOS only)
- `git/` - Git configuration
- `vim/` - Fallback vim configuration

## Symlink Mapping

The setup script creates these symlinks:
- `~/.zshrc` → `zsh/zshrc`
- `~/.zshenv` → `zsh/zshenv`
- `~/.config/nvim/` → `nvim/`
- `~/.tmux.conf` → `tmux/tmux.conf`
- `~/.config/starship.toml` → `starship/starship.toml`
- `~/.gitconfig` → `git/gitconfig`
- `~/.claude/{settings.json,hooks,skills}` → individual items in `claude/`

## Theme

Catppuccin Mocha is used consistently across Ghostty, fzf, Neovim, and tmux.
