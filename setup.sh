#!/bin/bash
#
# Dotfiles Setup Script
# This script sets up configuration files and plugins for zsh, vim, nvim, and tmux
# 

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
ZSH_PLUGINS_DIR="$HOME/.config/zsh/plugins"
DEV_DIR="$HOME/Developer/src"
TMUX_PLUGINS_DIR="$HOME/.tmux/plugins"
VIM_CATPPUCCIN_DIR="$HOME/.vim/pack/themes/start/catppuccin"
# The clone is this script's directory, not the caller's working directory.
# Physical path so links match what update.sh resolves with `cd -P`.
REPO_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTS_REPO_DIR=$REPO_DIR

# shellcheck source=lib/links.sh
source "$REPO_DIR/lib/links.sh"
# shellcheck source=lib/claude-hooks.sh
source "$REPO_DIR/lib/claude-hooks.sh"

# Print usage information
print_usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -f, --force             Force overwrite of existing config files without backup"
    echo "  -n, --dry-run           Show what would be done without making changes"
    echo "  -s, --skip-plugins      Skip plugin installation"
    echo "  -c, --check-nvchad      Check NVChad installation status and exit"
    echo "  -i, --install-font      Install JetBrains Mono Nerd Font (recommended for prompt symbols)"
    echo "  -y, --yes               Continue when commands are missing (no prompt)"
    echo "  -b, --brew              Install the Brewfile with Homebrew. On Linux this chooses Linuxbrew"
    echo "  -p, --profile <name>    Install a specific profile (repeatable, stackable)"
    echo
    echo "Profiles:"
    echo "  minimal   Shell essentials: zsh, starship, git, ghostty (default)"
    echo "  ai        AI tools: Claude Code config, llm skills/commands, Cursor CLI"
    echo "  full      Everything: minimal and ai, plus vim, tmux, Neovim, opencode,"
    echo "            btop, and a Nerd Font"
    echo
    echo "Profiles are composable. Combine them with multiple --profile flags:"
    echo "  $0 --profile minimal --profile ai"
    echo
    echo "Profile packages (separate from the Brewfile). Commands already on PATH are skipped:"
    echo "  minimal   zsh, git, starship, fzf, and zoxide"
    echo "  ai        jq (registers Claude Code hooks, merges Cursor CLI config)"
    echo "  full      also neovim (0.10+ for NvChad), tmux, and JetBrains Mono Nerd Font"
    echo "  macOS     Homebrew at /opt/homebrew (Apple Silicon) or /usr/local (Intel)"
    echo "  Linux     apt when apt-get exists (root or sudo; non-TTY needs passwordless sudo)."
    echo "            starship comes from its official installer into ~/.local/bin."
    echo "  --brew    On Linux, install those packages with Linuxbrew instead of apt"
    echo "pyenv, nvm, Bun, Claude, and Ghostty are never installed as requirements."
    echo
    echo "Update an existing install with ./update.sh (same directory as this script):"
    echo "  ./update.sh --help"
}

# Parse command line arguments
FORCE=false
DRY_RUN=false
SKIP_PLUGINS=false
CHECK_NVCHAD_ONLY=false
INSTALL_FONT=false
ASSUME_YES=false
INSTALL_BREW=false
PACKAGE_INSTALL_FAILED=false
SETUP_FAILURES=()
PROFILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-plugins)
            SKIP_PLUGINS=true
            shift
            ;;
        -c|--check-nvchad)
            CHECK_NVCHAD_ONLY=true
            shift
            ;;
        -i|--install-font)
            INSTALL_FONT=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -b|--brew)
            INSTALL_BREW=true
            shift
            ;;
        -p|--profile)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --profile requires a value (minimal, ai, full)"
                print_usage
                exit 1
            fi
            case $2 in
                minimal|ai|full)
                    PROFILES+=("$2")
                    ;;
                *)
                    echo -e "${RED}Error:${NC} Unknown profile: $2 (valid: minimal, ai, full)"
                    print_usage
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Default to minimal so a first run does not require vim, nvim, or tmux.
if [ ${#PROFILES[@]} -eq 0 ]; then
    PROFILES=("minimal")
fi

# Check if a profile is active
profile_active() {
    local target="$1"
    for p in "${PROFILES[@]}"; do
        if [[ "$p" == "full" || "$p" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# A recoverable step failed: keep going, but report it and exit nonzero.
record_failure() {
    SETUP_FAILURES+=("$1")
}

# NvChad needs Neovim 0.10+. Unparseable versions are not flagged.
nvim_version_ok() {
    local version major minor
    version=$(nvim --version 2>/dev/null | head -n1) || true
    version=${version#*v}
    major=${version%%.*}
    minor=${version#*.}
    minor=${minor%%.*}
    case "$major$minor" in
        ''|*[!0-9]*) return 0 ;;
    esac
    [ "$major" -gt 0 ] || [ "$minor" -ge 10 ]
}

# Missing commands used to prompt with `read`. A non-TTY run has nothing to
# read from, and `set -e` then aborts. --yes is the explicit assume-yes path.
# Without a terminal, continue instead of hanging or dying on `read`.
confirm_continue_missing() {
    if [ "$ASSUME_YES" = true ]; then
        log_info "Continuing because --yes was given."
        return 0
    fi

    if [ ! -t 0 ]; then
        log_warning "No terminal attached; not prompting. Continuing. Pass --yes to acknowledge missing commands."
        return 0
    fi

    local reply
    if ! read -r -n 1 -p "Continue anyway? (y/N) " reply; then
        echo
        log_warning "Could not read a response; continuing."
        return 0
    fi
    echo
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        log_error "Setup aborted."
        exit 1
    fi
}

# Check for required commands
check_requirements() {
    log_info "Checking requirements..."

    local missing_commands=()

    # Always need git (used to clone this repo)
    if ! command_exists git; then
        missing_commands+=("git")
    fi

    # zsh only needed for minimal profile
    if profile_active "minimal" && ! command_exists zsh; then
        missing_commands+=("zsh")
    fi

    # Only check for vim, nvim, tmux when full profile is active
    if profile_active "full"; then
        for cmd in vim nvim tmux; do
            if ! command_exists "$cmd"; then
                missing_commands+=("$cmd")
            fi
        done
    fi

    # jq registers the Claude Code hooks in settings.json
    if profile_active "ai" && ! command_exists jq; then
        missing_commands+=("jq")
    fi

    if profile_active "full" && command_exists nvim && ! nvim_version_ok; then
        log_warning "$(nvim --version 2>/dev/null | head -n1 || true) is older than 0.10; NvChad needs Neovim 0.10 or newer."
    fi

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_warning "The following required commands are missing:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        echo
        log_info "You may want to install them before continuing."
        confirm_continue_missing
    else
        log_success "All required commands are available."
    fi
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."

    local directories=()

    # Always create dev directory
    directories+=("$DEV_DIR")

    if profile_active "minimal"; then
        directories+=("$ZSH_PLUGINS_DIR")
    fi

    if profile_active "full"; then
        directories+=("$TMUX_PLUGINS_DIR")
        directories+=("$HOME/.config/opencode")
        directories+=("$HOME/.config/btop/themes")
    fi

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would create directory: $dir"
            else
                mkdir -p "$dir"
                log_success "Created directory: $dir"
            fi
        else
            log_info "Directory already exists: $dir"
        fi
    done
}

# Install plugins
install_plugins() {
    if [ "$SKIP_PLUGINS" = true ]; then
        log_info "Skipping plugin installation as requested."
        return
    fi

    log_info "Installing plugins..."

    if profile_active "minimal"; then
        log_info "ZSH plugins will be automatically installed by zinit on first shell launch"
    fi

    if profile_active "full"; then
        log_info "NVChad will be installed and configured for Neovim on first nvim launch"
        # Install Tmux Plugin Manager and plugins
        if ! install_tmux_plugins; then
            record_failure "Tmux Plugin Manager install"
        fi
        install_vim_catppuccin
    fi
}

# Catppuccin Mocha for plain vim, loaded as a native package
install_vim_catppuccin() {
    if [ -d "$VIM_CATPPUCCIN_DIR" ]; then
        log_info "Catppuccin vim theme already installed"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would clone Catppuccin vim theme into $VIM_CATPPUCCIN_DIR"
        return 0
    fi

    if ! command_exists git; then
        log_warning "git not found; skipping Catppuccin vim theme"
        return 0
    fi

    log_info "Installing Catppuccin vim theme"
    if mkdir -p "$(dirname "$VIM_CATPPUCCIN_DIR")" \
        && git clone --depth=1 https://github.com/catppuccin/vim "$VIM_CATPPUCCIN_DIR"; then
        log_success "Installed Catppuccin vim theme: $VIM_CATPPUCCIN_DIR"
    else
        rm -rf "$VIM_CATPPUCCIN_DIR"
        log_warning "Could not clone Catppuccin vim theme; vim falls back to its default colors"
    fi
}

# Install Tmux Plugin Manager and plugins
install_tmux_plugins() {
    log_info "Setting up Tmux plugins..."

    # Install Tmux Plugin Manager (tpm)
    if [ ! -d "$TMUX_PLUGINS_DIR/tpm" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would install Tmux Plugin Manager (tpm)"
        else
            log_info "Installing Tmux Plugin Manager (tpm)"
            if git clone --depth=1 https://github.com/tmux-plugins/tpm "$TMUX_PLUGINS_DIR/tpm"; then
                log_success "Installed Tmux Plugin Manager"
            else
                log_error "Failed to install Tmux Plugin Manager - this is a critical failure"
                log_error "Tmux plugin system will not work without TPM"
                return 1
            fi
        fi
    else
        log_info "Tmux Plugin Manager already installed"
    fi

    # tmux.conf is the only plugin list. Keeping one source of truth means
    # navigator, yank, Catppuccin Mocha, and future additions cannot be missed.
    if [ "$DRY_RUN" = false ] && [ -f "$TMUX_PLUGINS_DIR/tpm/bin/install_plugins" ]; then
        if ! command_exists tmux; then
            log_warning "tmux is not installed; TPM plugins install on first tmux start with prefix + I."
        elif [ ! -e "$HOME/.tmux.conf" ]; then
            log_warning "$HOME/.tmux.conf is not linked; skipping TPM plugin install."
        else
            log_info "Installing tmux plugins via TPM..."
            local tpm_output
            tpm_output=$(mktemp)
            if "$TMUX_PLUGINS_DIR/tpm/bin/install_plugins" >"$tpm_output" 2>&1; then
                log_success "Tmux plugins installed successfully"
            else
                log_warning "TPM plugin installation reported errors:"
                cat "$tpm_output"
            fi
            rm -f "$tpm_output"
        fi
    fi

    # Provide instructions for installing plugins via tpm
    if [ "$DRY_RUN" = false ]; then
        log_info "Tmux plugins installed. If you add new plugins to tmux.conf:"
        log_info "Run: ~/.tmux/plugins/tpm/bin/install_plugins"
        log_info "Or press prefix + I (capital I) in a tmux session"
    fi
}

# Move an existing config out of the way before linking.
# $2 is the repo-relative source: a symlink into a dots checkout at that path
# is ours and is simply removed; any other symlink is backed up like a file.
# $3 puts the backup in that directory instead of next to the original.
backup_config_file() {
    local file="$1"
    local rel="${2:-}"
    local backup_dir="${3:-}"
    local kind suffix backup_path

    if [ -L "$file" ]; then
        if [ -n "$rel" ] && checkout_root_for_link "$file" "$rel" >/dev/null; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would remove existing symlink: $file"
            else
                rm -f "$file"
                log_info "Removed existing symlink: $file"
            fi
            return 0
        fi
        kind="symlink"
        suffix="old"
    elif [ -d "$file" ]; then
        kind="directory"
        suffix="backup"
    elif [ -e "$file" ]; then
        kind="file"
        suffix="old"
    else
        return 0
    fi

    if [ "$FORCE" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would remove existing $kind without backup: $file"
        elif rm -rf "$file"; then
            log_warning "Removed existing $kind without backup: $file"
        else
            log_error "Failed to remove $kind: $file"
            return 1
        fi
        return 0
    fi

    if [ -n "$backup_dir" ]; then
        backup_path="$backup_dir/$(basename "$file").${suffix}_$(date +%F_%H-%M-%S)"
    else
        backup_path="${file}.${suffix}_$(date +%F_%H-%M-%S)"
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would backup $kind: $file → $backup_path"
        return 0
    fi

    if [ -n "$backup_dir" ] && ! mkdir -p "$backup_dir"; then
        log_error "Failed to create backup directory: $backup_dir"
        return 1
    fi
    if mv "$file" "$backup_path"; then
        log_success "Backed up $kind: $file → $backup_path"
    else
        log_error "Failed to backup $kind: $file"
        return 1
    fi
}

# Symlink $1 to $2. $3 is the repo-relative source, $4 is "optional" when a
# missing source is expected, $5 is passed on to backup_config_file.
# A link that already points at $1 is left alone. Returns 1 on failure.
link_item() {
    local source_path="$1"
    local target_path="$2"
    local rel="$3"
    local kind="${4:-required}"
    local backup_dir="${5:-}"

    if [ ! -e "$source_path" ]; then
        [ "$kind" = optional ] && return 0
        log_error "Source file does not exist: $source_path"
        return 1
    fi

    if [ -L "$target_path" ] && [ -e "$target_path" ] \
        && [ "$(readlink "$target_path")" = "$source_path" ]; then
        return 0
    fi

    if ! backup_config_file "$target_path" "$rel" "$backup_dir"; then
        log_error "Backup failed for $target_path, skipping to prevent data loss"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would link: $source_path → $target_path"
        return 0
    fi

    if ! mkdir -p "$(dirname "$target_path")"; then
        log_error "Failed to create parent directory for $target_path"
        return 1
    fi
    if ! ln -sfn "$source_path" "$target_path"; then
        log_error "Failed to create symlink: $source_path → $target_path"
        return 1
    fi
    if [ -L "$target_path" ] && [ -e "$target_path" ]; then
        log_success "Linked: $source_path → $target_path"
        return 0
    fi
    log_error "Symlink created but target is broken: $target_path"
    rm -f "$target_path"
    return 1
}

# ~/.claude/skills and ~/.claude/commands are real directories so externally
# installed skills and commands can coexist without polluting the repo.
prepare_claude_item_dir() {
    local dir="$1"
    if [ -L "$dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would replace symlink with a directory: $dir"
            return 0
        fi
        rm -f "$dir"
        log_info "Removed old symlink: $dir"
    elif [ -d "$dir" ]; then
        return 0
    elif [ "$DRY_RUN" = true ]; then
        log_info "Would create directory: $dir"
        return 0
    fi
    mkdir -p "$dir"
}

# Link config files listed in lib/links.sh
link_config_files() {
    log_info "Linking configuration files..."

    local table profile kind rel target_path
    local link_failures=0
    local extra_failures=0

    table=$(dots_link_table)
    while IFS='|' read -r profile kind rel target_path; do
        profile_active "$profile" || continue
        if ! link_item "$REPO_DIR/$rel" "$target_path" "$rel" "$kind"; then
            link_failures=$((link_failures + 1))
        fi
    done <<< "$table"

    if profile_active "ai"; then
        link_claude_extras || extra_failures=$?
        link_failures=$((link_failures + extra_failures))
    fi

    if [ "$link_failures" -gt 0 ]; then
        record_failure "$link_failures config link(s)"
    fi
}

# Hook registration, skills, and commands for the ai profile.
# Returns the number of links that failed.
link_claude_extras() {
    local claude_target="$HOME/.claude"
    local llm_source="$REPO_DIR/llm"
    local skills_target="$claude_target/skills"
    local commands_target="$claude_target/commands"
    local failures=0
    local skill_dir skill_name cmd_file cmd_name

    # Register the portable hooks in the machine-local settings.json
    if ! merge_claude_hooks \
        "$REPO_DIR/claude/settings.hooks.json" \
        "$claude_target/settings.json" \
        "$claude_target/hooks"; then
        record_failure "Claude hook merge"
    fi

    [ -d "$llm_source" ] || return 0

    prepare_claude_item_dir "$skills_target"
    # Backups stay outside skills/, where Claude would load them as duplicates.
    for skill_dir in "$llm_source"/skills/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        if ! link_item "${skill_dir%/}" "$skills_target/$skill_name" \
            "llm/skills/$skill_name" required "$claude_target/skills.backup"; then
            failures=$((failures + 1))
        fi
    done

    prepare_claude_item_dir "$commands_target"
    for cmd_file in "$llm_source"/commands/*; do
        [ -e "$cmd_file" ] || continue
        cmd_name=$(basename "$cmd_file")
        if ! link_item "$cmd_file" "$commands_target/$cmd_name" "llm/commands/$cmd_name"; then
            failures=$((failures + 1))
        fi
    done

    return "$failures"
}

# The homelab skills source ~/.config/homelab/devices.env
install_homelab_devices_env() {
    if ! profile_active "ai"; then
        return
    fi

    local template_file="$REPO_DIR/llm/devices.env.template"
    local target_file="$HOME/.config/homelab/devices.env"

    if [ ! -f "$template_file" ] || [ -e "$target_file" ]; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would copy template: $template_file → $target_file"
        return
    fi

    if mkdir -p "$(dirname "$target_file")" && cp "$template_file" "$target_file" \
        && chmod 600 "$target_file"; then
        log_success "Copied homelab devices template: $target_file"
        log_info "Fill in $target_file for the homelab skills"
    else
        log_warning "Failed to copy homelab devices template to $target_file"
    fi
}

# Merge portable Cursor CLI preferences into ~/.cursor/cli-config.json.
# Cursor rewrites that file with auth and cache data, so it is not symlinked.
install_cursor_cli_config() {
    if ! profile_active "ai"; then
        return 0
    fi

    local merge_helper="$REPO_DIR/lib/cursor-config.sh"
    if [ ! -f "$merge_helper" ]; then
        log_error "Cursor CLI merge helper not found: $merge_helper"
        return 0
    fi

    # shellcheck source=lib/cursor-config.sh
    source "$merge_helper"
    if ! merge_cursor_cli_config \
        "$REPO_DIR/cursor/cli-config.json" \
        "$HOME/.cursor/cli-config.json" \
        "$DRY_RUN"; then
        log_warning "Cursor CLI preferences were not changed."
        record_failure "Cursor CLI config merge"
    fi
}

# Install gitconfig.local template if not present
install_gitconfig_local() {
    if ! profile_active "minimal"; then
        return
    fi

    local template_file
    template_file="$REPO_DIR/git/gitconfig.local.template"
    local target_file="$HOME/.gitconfig.local"

    if [ ! -f "$template_file" ]; then
        log_warning "gitconfig.local.template not found: $template_file"
        return
    fi

    if [ -f "$target_file" ]; then
        log_info "Local git config already exists: $target_file"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would copy template: $template_file → $target_file"
    else
        if cp "$template_file" "$target_file"; then
            log_success "Copied gitconfig.local template: $target_file"
            log_info "Edit $target_file to set your git identity (name and email)"
        else
            log_error "Failed to copy gitconfig.local template"
        fi
    fi
}

# Check NVChad installation
check_nvchad() {
    echo
    log_info "Checking NVChad installation..."

    # Check if nvim config symlink exists
    if [ -L "$HOME/.config/nvim" ]; then
        local target
        target=$(readlink "$HOME/.config/nvim")
        log_success "NVChad config symlinked: $HOME/.config/nvim -> $target"
    elif [ -d "$HOME/.config/nvim" ]; then
        log_warning "$HOME/.config/nvim exists but is not a symlink"
    else
        log_error "$HOME/.config/nvim not found"
        return 1
    fi

    # Check if init.lua exists
    if [ -f "$HOME/.config/nvim/init.lua" ]; then
        log_success "init.lua found"
    else
        log_error "init.lua not found in nvim config"
        return 1
    fi

    # Check if lazy.nvim is installed
    if [ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
        log_success "lazy.nvim plugin manager installed"
    else
        log_warning "lazy.nvim not installed (will be installed on first nvim launch)"
    fi

    # Check if NVChad is installed
    if [ -d "$HOME/.local/share/nvim/lazy/NvChad" ]; then
        log_success "NVChad base plugin installed"
    else
        log_warning "NVChad base plugin not installed (will be installed on first nvim launch)"
    fi

    # Check neovim version
    if command_exists nvim; then
        local nvim_version
        nvim_version=$(nvim --version | head -n1)
        log_info "Neovim version: $nvim_version"
    fi

    echo
}

# Install NVChad plugins
install_nvchad() {
    if [ "$SKIP_PLUGINS" = true ]; then
        log_info "Skipping NVChad plugin installation as requested."
        return
    fi

    if ! command_exists nvim; then
        log_warning "Neovim not found. Skipping NVChad plugin installation."
        return
    fi

    if [ ! -d "$HOME/.config/nvim" ]; then
        log_warning "NVChad config not found. Skipping plugin installation."
        return
    fi

    log_info "Installing NVChad plugins (this may take a minute)..."

    if [ "$DRY_RUN" = true ]; then
        log_info "Would install NVChad plugins"
        return
    fi

    # Run nvim headlessly to install plugins
    local install_output
    install_output=$(mktemp)
    if nvim --headless "+Lazy! sync" +qa > "$install_output" 2>&1; then
        log_success "NVChad plugins installed successfully"
    else
        log_warning "NVChad plugin installation may have errors. Output:"
        cat "$install_output"
    fi
    rm -f "$install_output"
}

# Install JetBrains Mono Nerd Font
install_font() {
    if [ "$INSTALL_FONT" = false ]; then
        return
    fi

    log_info "Attempting to install JetBrains Mono Nerd Font..."

    local font_dir
    if [[ "$(uname)" == "Darwin" ]]; then
        font_dir="$HOME/Library/Fonts"
    elif [[ "$(uname)" == "Linux" ]]; then
        font_dir="$HOME/.local/share/fonts"
    else
        log_warning "Font installation not supported on this OS."
        return
    fi

    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local font_check_file="JetBrainsMonoNerdFontMono-Regular.ttf"

    if [ ! -d "$font_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create font directory: $font_dir"
        else
            mkdir -p "$font_dir"
            log_success "Created font directory: $font_dir"
        fi
    fi

    if [ ! -f "$font_dir/$font_check_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would download and extract JetBrains Mono Nerd Font to $font_dir"
        else
            if ! command_exists unzip; then
                log_error "unzip command not found. Cannot extract font archive."
                return
            fi

            local temp_dir
            temp_dir=$(mktemp -d)
            local zip_file="$temp_dir/JetBrainsMono.zip"

            log_info "Downloading JetBrains Mono Nerd Font..."
            local download_success=false
            if command_exists curl; then
                if curl -fLo "$zip_file" "$font_url"; then
                    download_success=true
                fi
            elif command_exists wget; then
                if wget -qO "$zip_file" "$font_url"; then
                    download_success=true
                fi
            else
                log_error "Neither curl nor wget found. Cannot download font."
                rm -rf "$temp_dir"
                return
            fi

            if [ "$download_success" = true ]; then
                log_info "Extracting fonts..."
                if unzip -q "$zip_file" -d "$temp_dir"; then
                    # Copy only the Mono variant ttf files (not variable fonts)
                    local fonts_copied=0
                    for ttf in "$temp_dir"/JetBrainsMonoNerdFontMono-*.ttf; do
                        if [ -f "$ttf" ]; then
                            cp "$ttf" "$font_dir/"
                            fonts_copied=$((fonts_copied + 1))
                        fi
                    done
                    if [ "$fonts_copied" -gt 0 ]; then
                        log_success "Installed $fonts_copied JetBrains Mono Nerd Font files to $font_dir"
                    else
                        log_error "No font files found in archive"
                    fi

                    # On Linux, refresh font cache
                    if [[ "$(uname)" == "Linux" ]] && command_exists fc-cache; then
                        log_info "Updating font cache..."
                        fc-cache -fv >/dev/null 2>&1
                        log_success "Font cache updated."
                    fi
                else
                    log_error "Failed to extract font archive."
                fi
            else
                log_error "Failed to download font archive."
            fi

            rm -rf "$temp_dir"
        fi
    else
        log_info "JetBrains Mono Nerd Font already installed at $font_dir"
    fi
}

# Homebrew binary for this OS. Does not run brew.
# PATH first, then Darwin: Apple Silicon, Intel; Linux: Linuxbrew prefixes.
find_brew() {
    local candidate
    local os

    # The brew on PATH is the one this shell already uses; honour it first.
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    os=$(uname)
    if [ "$os" = "Darwin" ]; then
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            if [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    else
        for candidate in "${HOME}/.linuxbrew/bin/brew" /home/linuxbrew/.linuxbrew/bin/brew; do
            if [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi
    return 1
}

# Linux shells source Linuxbrew only after this marker exists, or DOTS_USE_BREW=1.
mark_linuxbrew_chosen() {
    local marker="${HOME}/.config/zsh/use-brew"
    if [ "$DRY_RUN" = true ]; then
        log_info "Would write Linuxbrew opt-in: $marker"
        return 0
    fi
    mkdir -p "${HOME}/.config/zsh"
    printf '%s\n' "DOTS_USE_BREW=1" > "$marker"
    log_success "Linuxbrew opt-in written: $marker"
}

install_with_brew() {
    local brew_bin
    local os
    os=$(uname)

    if ! brew_bin=$(find_brew); then
        if [ "$os" = "Darwin" ]; then
            log_warning "Homebrew not found at /opt/homebrew/bin/brew (Apple Silicon) or /usr/local/bin/brew (Intel)."
        else
            log_warning "Linuxbrew not found at ~/.linuxbrew or /home/linuxbrew/.linuxbrew."
        fi
        log_warning "Install it from https://brew.sh/ and re-run. Not installing: $*"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would run: $brew_bin install $*"
        return 0
    fi

    log_info "Installing with Homebrew: $*"
    if ! "$brew_bin" install "$@"; then
        log_error "brew install failed for required packages: $*"
        return 1
    fi
    log_success "Homebrew packages installed: $*"
}

# Report how to get a package neither apt nor a known installer provides.
apt_alternative_hint() {
    log_info "  $1: install it manually, or re-run with --brew to use Linuxbrew"
}

# Official installer, non-interactive: --yes, into ~/.local/bin (on PATH via
# zshenv). Downloaded to a file first so the run is not a blind curl | sh.
install_starship_fallback() {
    local bin_dir="$HOME/.local/bin"
    local installer

    if [ "$DRY_RUN" = true ]; then
        log_info "Would install starship with the official installer into $bin_dir"
        return 0
    fi
    if ! command_exists curl; then
        log_error "curl is required to install starship without apt."
        return 1
    fi
    installer=$(mktemp)
    if ! curl -fsSLo "$installer" https://starship.rs/install.sh; then
        log_error "Could not download the starship installer."
        rm -f "$installer"
        return 1
    fi
    mkdir -p "$bin_dir"
    if sh "$installer" --yes --bin-dir "$bin_dir"; then
        rm -f "$installer"
        log_success "Installed starship into $bin_dir"
        return 0
    fi
    rm -f "$installer"
    log_error "The starship installer failed."
    return 1
}

# Non-apt install path for one package. Returns 2 when none is known.
install_apt_fallback() {
    case "$1" in
        starship) install_starship_fallback ;;
        *) return 2 ;;
    esac
}

# apt-get install aborts the whole transaction when one name is unknown, so a
# single missing package (starship is in no Debian or Ubuntu repo) used to drop
# zsh and git too. Probe each name with apt-cache first and install only what
# this apt actually has; report the rest instead of installing nothing.
install_with_apt() {
    local requested=("$@")
    local sudo_cmd=()
    local available=()
    local unavailable=()
    local installed=()
    local failed=()
    local pkg status

    if [ ${#requested[@]} -eq 0 ]; then
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        if [ "$(id -u)" -eq 0 ]; then
            log_info "Would run: apt-get update"
        else
            log_info "Would run: sudo apt-get update"
        fi
        log_info "Would probe each package with: apt-cache show <pkg> (${requested[*]})"
        log_info "Would install each available package independently so one failure does not block the others."
        log_info "Would report any package apt cannot provide, with how to install it instead."
        log_info "Would install starship with its official installer if apt cannot provide it."
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        sudo_cmd=(sudo)
        if [ ! -t 0 ]; then
            if ! sudo -n true >/dev/null 2>&1; then
                log_error "apt needs a sudo password and stdin is not a terminal. Not installing: ${requested[*]}"
                return 1
            fi
            sudo_cmd=(sudo -n)
        fi
    fi

    log_info "Installing with apt: ${requested[*]}"

    # bash 3.2 (macOS) treats "${arr[@]}" on an empty array as unbound under
    # `set -u`; as root sudo_cmd is empty, and so is available when apt has
    # none of the packages.
    if ! ${sudo_cmd[@]+"${sudo_cmd[@]}"} apt-get update; then
        log_warning "apt-get update failed. Continuing with the package lists already on disk."
    fi

    for pkg in "${requested[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            available+=("$pkg")
        else
            unavailable+=("$pkg")
        fi
    done

    for pkg in ${available[@]+"${available[@]}"}; do
        if ${sudo_cmd[@]+"${sudo_cmd[@]}"} env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
            installed+=("$pkg")
        else
            failed+=("$pkg")
        fi
    done

    for pkg in ${unavailable[@]+"${unavailable[@]}"}; do
        log_warning "apt cannot provide $pkg; trying its official installer."
        status=0
        install_apt_fallback "$pkg" || status=$?
        case "$status" in
            0) installed+=("$pkg") ;;
            2)
                log_error "apt cannot provide required package: $pkg"
                apt_alternative_hint "$pkg"
                failed+=("$pkg")
                ;;
            *) failed+=("$pkg") ;;
        esac
    done

    if [ ${#installed[@]} -gt 0 ]; then
        log_success "Packages installed: ${installed[*]}"
    fi
    if [ ${#failed[@]} -gt 0 ]; then
        log_error "Required packages not installed: ${failed[*]}"
        return 1
    fi
    return 0
}

# Command a profile package provides, to detect it is already installed.
package_command() {
    case "$1" in
        neovim) printf '%s\n' nvim ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# minimal: zsh, git, starship, fzf, zoxide. ai: jq. full also: neovim, tmux.
# Packages whose command is already on PATH are skipped, so a re-run does not
# touch apt (or brew-install a second zsh and git on macOS).
# Font for full is install_font, not a package-manager formula.
# pyenv, nvm, Bun, Claude, and Ghostty are not in this list.
install_profile_packages() {
    local wanted=()
    local packages=()
    local present=()
    local pkg
    local os

    if profile_active "minimal"; then
        wanted+=(zsh git starship fzf zoxide)
    fi
    if profile_active "ai"; then
        wanted+=(jq)
    fi
    if profile_active "full"; then
        wanted+=(neovim tmux)
    fi

    if [ ${#wanted[@]} -eq 0 ]; then
        log_info "Active profile does not install packages. pyenv, nvm, Bun, Claude, and Ghostty stay optional."
        return 0
    fi

    for pkg in "${wanted[@]}"; do
        if command_exists "$(package_command "$pkg")"; then
            present+=("$pkg")
        else
            packages+=("$pkg")
        fi
    done

    if [ ${#present[@]} -gt 0 ]; then
        log_info "Profile packages already installed: ${present[*]}"
    fi
    if [ ${#packages[@]} -eq 0 ]; then
        return 0
    fi

    os=$(uname)
    log_info "Profile packages (${os}): ${packages[*]}"

    if [ "$os" = "Darwin" ]; then
        install_with_brew "${packages[@]}"
        return $?
    fi

    if [ "$os" = "Linux" ]; then
        if [ "$INSTALL_BREW" = true ]; then
            log_info "Using Linuxbrew because --brew was given."
            install_with_brew "${packages[@]}"
            return $?
        fi
        if command_exists apt-get; then
            install_with_apt "${packages[@]}"
            return $?
        fi
        log_warning "This Linux system does not use apt (apt-get not found)."
        log_warning "Not installing packages. Pass --brew to use Linuxbrew, or install manually: ${packages[*]}"
        return 0
    fi

    log_warning "No package install path for ${os}. Not installing: ${packages[*]}"
}

install_brew_packages() {
    if [ "$INSTALL_BREW" = false ]; then
        return 0
    fi

    local os
    local brew_bin
    local brewfile
    os=$(uname)

    if [ "$os" != "Linux" ] && [ "$os" != "Darwin" ]; then
        log_warning "Brewfile install is not supported on ${os}. Skipping."
        return 0
    fi

    if ! brew_bin=$(find_brew); then
        log_warning "Homebrew not found. Install it from https://brew.sh/ first. Skipping Brewfile."
        return 0
    fi

    # Only opt the shell into Linuxbrew once find_brew has actually located it,
    # so a --brew run without brew never leaves a marker pointing at nothing.
    if [ "$os" = "Linux" ]; then
        mark_linuxbrew_chosen
    fi

    brewfile="$REPO_DIR/Brewfile"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would install Homebrew packages from $brewfile ($brew_bin bundle install)"
        return 0
    fi

    log_info "Installing Homebrew packages from Brewfile..."
    if "$brew_bin" bundle install --file="$brewfile"; then
        log_success "Homebrew packages installed."
    else
        log_error "brew bundle failed. Re-run '$brew_bin bundle --file=$brewfile' to retry."
        record_failure "Brewfile install"
    fi
}

# chsh can prompt for a password, so only say how.
suggest_login_shell() {
    if ! profile_active "minimal" || [ "$(uname)" != "Linux" ] || ! command_exists zsh; then
        return
    fi
    case "${SHELL:-}" in
        */zsh) ;;
        *) log_info "Your login shell is ${SHELL:-unknown}. Switch to zsh with: chsh -s \"$(command -v zsh)\"" ;;
    esac
}

# Main function
main() {
    # If check-nvchad flag is set, only run the check
    if [ "$CHECK_NVCHAD_ONLY" = true ]; then
        echo -e "${BOLD}NVChad Status Check${NC}"
        echo "===================="
        # A deliberate status query, so keep a meaningful exit code — but set it
        # explicitly instead of letting `set -e` kill the script mid-function.
        local nvchad_status=0
        check_nvchad || nvchad_status=$?
        exit "$nvchad_status"
    fi

    echo -e "${BOLD}Dotfiles Setup${NC}"
    echo "===================="
    echo

    if [ "$DRY_RUN" = true ]; then
        log_warning "Running in dry-run mode. No changes will be made."
        echo
    fi

    log_info "Active profiles: ${PROFILES[*]}"
    echo

    install_brew_packages
    if ! install_profile_packages; then
        PACKAGE_INSTALL_FAILED=true
    fi
    if profile_active "full"; then
        INSTALL_FONT=true
    fi
    check_requirements
    create_directories
    install_font
    link_config_files
    install_gitconfig_local
    install_cursor_cli_config
    install_homelab_devices_env
    # After linking: TPM reads its @plugin list from ~/.tmux.conf.
    install_plugins

    if profile_active "full"; then
        install_nvchad
        # Informational only: a machine that has not linked nvim yet is not a
        # setup failure, so never let this abort the run under `set -e`.
        check_nvchad || true
    fi

    echo
    if [ "$PACKAGE_INSTALL_FAILED" = true ]; then
        log_error "Required package installation failed. Setup completed the remaining safe steps."
    fi
    if [ ${#SETUP_FAILURES[@]} -gt 0 ]; then
        local joined
        joined=$(printf '%s, ' "${SETUP_FAILURES[@]}")
        log_error "Setup finished with failures: ${joined%, }"
    fi
    if [ "$PACKAGE_INSTALL_FAILED" = false ] && [ ${#SETUP_FAILURES[@]} -eq 0 ]; then
        log_success "Setup completed successfully!"
    fi
    if profile_active "minimal"; then
        log_info "You may need to restart your shell or run 'source ~/.zshrc' to apply changes."
        log_info "Zinit will automatically install ZSH plugins on first shell launch."
    fi
    suggest_login_shell
    if profile_active "full"; then
        log_info "To activate tmux plugins, start tmux and press prefix + I (capital I)."
    fi
    if [ "$PACKAGE_INSTALL_FAILED" = true ] || [ ${#SETUP_FAILURES[@]} -gt 0 ]; then
        return 1
    fi
}

# Run the main function
main

exit 0
