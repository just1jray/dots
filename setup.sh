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
TMUX_PLUGIN_RESURRECT_DIR="$HOME/.tmux/plugins/resurrect"

# Print usage information
print_usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force overwrite of existing config files without backup"
    echo "  -n, --dry-run       Show what would be done without making changes"
    echo "  -s, --skip-plugins  Skip plugin installation"
    echo "  -c, --check-nvchad  Check NVChad installation status and exit"
    echo "  -i, --install-font  Install MesloLGS NF font (recommended for prompt symbols)"
    echo
    echo "This script sets up dotfiles for zsh, vim, nvim, and tmux."
    echo "It creates necessary directories, installs plugins, and symlinks config files."
}

# Parse command line arguments
FORCE=false
DRY_RUN=false
SKIP_PLUGINS=false
CHECK_NVCHAD_ONLY=false
INSTALL_FONT=false

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
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

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

# Check for required commands
check_requirements() {
    log_info "Checking requirements..."
    
    local missing_commands=()
    
    for cmd in git zsh vim nvim tmux; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_warning "The following required commands are missing:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        echo
        log_info "You may want to install them before continuing."
        
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Setup aborted."
            exit 1
        fi
    else
        log_success "All required commands are available."
    fi
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."

    local directories=(
        "$ZSH_PLUGINS_DIR"
        "$DEV_DIR"
        "$TMUX_PLUGINS_DIR"
        "$TMUX_PLUGIN_RESURRECT_DIR"
    )

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

    # Note: ZSH plugins are now managed by zinit and will be installed automatically
    # Note: Neovim is now managed by NVChad and will be configured on first launch

    log_info "ZSH plugins will be automatically installed by zinit on first shell launch"
    log_info "NVChad will be installed and configured for Neovim on first nvim launch"

    # Install Tmux Plugin Manager and plugins
    install_tmux_plugins
}

# Install Tmux Plugin Manager and plugins
install_tmux_plugins() {
    log_info "Setting up Tmux plugins..."

    local failed_plugins=()

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
    
    # Define Tmux plugins to install directly
    local tmux_plugins=(
        "https://github.com/tmux-plugins/tmux-sensible|$TMUX_PLUGINS_DIR/tmux-sensible"
        "https://github.com/tmux-plugins/tmux-battery|$TMUX_PLUGINS_DIR/tmux-battery"
        "https://github.com/tmux-plugins/tmux-resurrect|$TMUX_PLUGINS_DIR/tmux-resurrect"
        "https://github.com/tmux-plugins/tmux-continuum|$TMUX_PLUGINS_DIR/tmux-continuum"
    )
    
    # Install each Tmux plugin
    for plugin in "${tmux_plugins[@]}"; do
        IFS='|' read -r repo_url install_dir <<< "$plugin"
        plugin_name=$(basename "$install_dir")

        if [ ! -d "$install_dir" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would install Tmux plugin: $plugin_name"
            else
                log_info "Installing Tmux plugin: $plugin_name"
                if git clone --depth=1 "$repo_url" "$install_dir"; then
                    log_success "Installed Tmux plugin: $plugin_name"
                else
                    log_error "Failed to install Tmux plugin: $plugin_name"
                    failed_plugins+=("$plugin_name")
                fi
            fi
        else
            log_info "Tmux plugin already installed: $plugin_name"
        fi
    done

    # Report any failures
    if [ ${#failed_plugins[@]} -gt 0 ]; then
        log_warning "Some tmux plugins failed to install:"
        for plugin in "${failed_plugins[@]}"; do
            echo "  - $plugin"
        done
        log_warning "These plugins can be installed later via: ~/.tmux/plugins/tpm/bin/install_plugins"
    fi

    # Install all plugins defined in tmux.conf via TPM
    if [ "$DRY_RUN" = false ] && [ -f "$TMUX_PLUGINS_DIR/tpm/bin/install_plugins" ]; then
        log_info "Installing tmux plugins via TPM..."
        if "$TMUX_PLUGINS_DIR/tpm/bin/install_plugins" > /dev/null 2>&1; then
            log_success "Tmux plugins installed successfully"
        else
            log_warning "TPM plugin installation completed with some warnings"
        fi
    fi

    # Provide instructions for installing plugins via tpm
    if [ "$DRY_RUN" = false ]; then
        log_info "Tmux plugins installed. If you add new plugins to tmux.conf:"
        log_info "Run: ~/.tmux/plugins/tpm/bin/install_plugins"
        log_info "Or press prefix + I (capital I) in a tmux session"
    fi
}

# Backup existing config file or directory
backup_config_file() {
    local file="$1"

    # Handle regular files
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would remove existing file without backup: $file"
            else
                if rm -f "$file"; then
                    log_warning "Removed existing file without backup: $file"
                else
                    log_error "Failed to remove file: $file"
                    return 1
                fi
            fi
        else
            local backup_file
            backup_file="${file}.old_$(date +%F_%H-%M-%S)"
            if [ "$DRY_RUN" = true ]; then
                log_info "Would backup file: $file → $backup_file"
            else
                if mv "$file" "$backup_file"; then
                    log_success "Backed up file: $file → $backup_file"
                else
                    log_error "Failed to backup file: $file"
                    return 1
                fi
            fi
        fi
    # Handle directories (not symlinks)
    elif [ -d "$file" ] && [ ! -L "$file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would remove existing directory without backup: $file"
            else
                if rm -rf "$file"; then
                    log_warning "Removed existing directory without backup: $file"
                else
                    log_error "Failed to remove directory: $file"
                    return 1
                fi
            fi
        else
            local backup_dir
            backup_dir="${file}.backup_$(date +%F_%H-%M-%S)"
            if [ "$DRY_RUN" = true ]; then
                log_info "Would backup directory: $file → $backup_dir"
            else
                if mv "$file" "$backup_dir"; then
                    log_success "Backed up directory: $file → $backup_dir"
                else
                    log_error "Failed to backup directory: $file"
                    return 1
                fi
            fi
        fi
    # Handle symlinks
    elif [ -L "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would remove existing symlink: $file"
        else
            rm -f "$file"
            log_info "Removed existing symlink: $file"
        fi
    fi
}

# Link config files
link_config_files() {
    log_info "Linking configuration files..."

    local config_files=(
        "zsh/zshrc|$HOME/.zshrc"
        "zsh/zshenv|$HOME/.zshenv"
        "vim/vimrc|$HOME/.vimrc"
        "tmux/tmux.conf|$HOME/.tmux.conf"
        "starship/starship.toml|$HOME/.config/starship.toml"
        "git/gitconfig|$HOME/.gitconfig"
        "git/gitignore_global|$HOME/.gitignore_global"
    )

    # Add Ghostty config only on macOS
    if [[ $(uname) == "Darwin" ]]; then
        config_files+=("ghostty/config|$HOME/Library/Application Support/com.mitchellh.ghostty/config")
    fi

    # Add aliases file if it exists
    if [ -f "$(pwd)/zsh/aliases" ]; then
        config_files+=("zsh/aliases|$HOME/.config/zsh/aliases")
    fi

    # Add hosts file if it exists
    if [ -f "$(pwd)/zsh/hosts" ]; then
        config_files+=("zsh/hosts|$HOME/.config/zsh/hosts")
    fi

    # Add platform-specific profile files if they exist
    if [ -f "$(pwd)/zsh/profile-macos" ]; then
        config_files+=("zsh/profile-macos|$HOME/.config/zsh/profile-macos")
    fi

    if [ -f "$(pwd)/zsh/profile-linux" ]; then
        config_files+=("zsh/profile-linux|$HOME/.config/zsh/profile-linux")
    fi

    for config in "${config_files[@]}"; do
        IFS='|' read -r source_file target_file <<< "$config"
        source_path="$(pwd)/$source_file"

        if [ ! -f "$source_path" ]; then
            log_warning "Source file does not exist: $source_path"
            continue
        fi

        if ! backup_config_file "$target_file"; then
            log_error "Backup failed for $target_file, skipping to prevent data loss"
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            log_info "Would link file: $source_path → $target_file"
        else
            if ln -sf "$source_path" "$target_file"; then
                # Verify symlink was created and target exists
                if [ -L "$target_file" ] && [ -e "$target_file" ]; then
                    log_success "Linked file: $source_path → $target_file"
                else
                    log_error "Symlink created but target is broken: $target_file"
                    log_error "Source may not exist: $source_path"
                    rm -f "$target_file"  # Remove broken symlink
                fi
            else
                log_error "Failed to create symlink: $source_path → $target_file"
            fi
        fi
    done

    # Link NVChad config directory
    local nvim_source
    nvim_source="$(pwd)/nvim"
    local nvim_target="$HOME/.config/nvim"

    if [ -d "$nvim_source" ]; then
        if ! backup_config_file "$nvim_target"; then
            log_error "Backup failed for $nvim_target, skipping to prevent data loss"
            return 1
        fi

        if [ "$DRY_RUN" = true ]; then
            log_info "Would link directory: $nvim_source → $nvim_target"
        else
            if ln -sf "$nvim_source" "$nvim_target"; then
                # Verify symlink was created and target exists
                if [ -L "$nvim_target" ] && [ -e "$nvim_target" ]; then
                    log_success "Linked NVChad config: $nvim_source → $nvim_target"
                else
                    log_error "Symlink created but target is broken: $nvim_target"
                    log_error "Source may not exist: $nvim_source"
                    rm -f "$nvim_target"  # Remove broken symlink
                fi
            else
                log_error "Failed to create symlink: $nvim_source → $nvim_target"
            fi
        fi
    else
        log_warning "NVChad config directory does not exist: $nvim_source"
    fi

    # Link Claude Code config files (only portable settings, not ephemeral data)
    local claude_source
    claude_source="$(pwd)/claude"
    local claude_target="$HOME/.claude"

    if [ -d "$claude_source" ]; then
        # Create ~/.claude directory if it doesn't exist (Claude Code manages ephemeral data here)
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create directory: $claude_target"
        else
            mkdir -p "$claude_target"
        fi

        # Symlink individual portable config files/directories
        local claude_items=("settings.json" "hooks" "skills" "CLAUDE.md")
        for item in "${claude_items[@]}"; do
            local item_source="$claude_source/$item"
            local item_target="$claude_target/$item"

            if [ -e "$item_source" ] || [ -L "$item_source" ]; then
                if ! backup_config_file "$item_target"; then
                    log_error "Backup failed for $item_target, skipping"
                    continue
                fi

                if [ "$DRY_RUN" = true ]; then
                    log_info "Would link: $item_source → $item_target"
                else
                    if ln -sf "$item_source" "$item_target"; then
                        if [ -L "$item_target" ] && [ -e "$item_target" ]; then
                            log_success "Linked Claude Code config: $item → $item_target"
                        else
                            log_error "Symlink created but target is broken: $item_target"
                            rm -f "$item_target"
                        fi
                    else
                        log_error "Failed to create symlink: $item_source → $item_target"
                    fi
                fi
            fi
        done
    else
        log_warning "Claude Code config directory does not exist: $claude_source"
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

# Install MesloLGS NF Font
install_font() {
    if [ "$INSTALL_FONT" = false ]; then
        return
    fi

    log_info "Attempting to install MesloLGS NF Font..."

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        local font_dir="$HOME/Library/Fonts"
        local font_url="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        local font_file="MesloLGS NF Regular.ttf"
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        local font_dir="$HOME/.local/share/fonts"
        local font_url="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        local font_file="MesloLGS NF Regular.ttf"
    else
        log_warning "Font installation not supported on this OS."
        return
    fi

    if [ ! -d "$font_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create font directory: $font_dir"
        else
            mkdir -p "$font_dir"
            log_success "Created font directory: $font_dir"
        fi
    fi

    if [ ! -f "$font_dir/$font_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Would download font from $font_url to $font_dir/$font_file"
        else
            log_info "Downloading $font_file..."
            if command_exists curl; then
                if curl -fLo "$font_dir/$font_file" "$font_url"; then
                    log_success "Downloaded $font_file to $font_dir"
                    # On Linux, refresh font cache
                    if [[ "$(uname)" == "Linux" ]] && command_exists fc-cache; then
                        log_info "Updating font cache..."
                        fc-cache -fv >/dev/null 2>&1
                        log_success "Font cache updated."
                    fi
                else
                    log_error "Failed to download $font_file using curl."
                fi
            elif command_exists wget; then
                if wget -qO "$font_dir/$font_file" "$font_url"; then
                    log_success "Downloaded $font_file to $font_dir"
                    # On Linux, refresh font cache
                    if [[ "$(uname)" == "Linux" ]] && command_exists fc-cache; then
                        log_info "Updating font cache..."
                        fc-cache -fv >/dev/null 2>&1
                        log_success "Font cache updated."
                    fi
                else
                    log_error "Failed to download $font_file using wget."
                fi
            else
                log_error "Neither curl nor wget found. Cannot download font."
            fi
        fi
    else
        log_info "MesloLGS NF Font already exists at $font_dir/$font_file"
    fi
}

# Main function
main() {
    # If check-nvchad flag is set, only run the check
    if [ "$CHECK_NVCHAD_ONLY" = true ]; then
        echo -e "${BOLD}NVChad Status Check${NC}"
        echo "===================="
        check_nvchad
        exit 0
    fi

    echo -e "${BOLD}Dotfiles Setup${NC}"
    echo "===================="
    echo

    if [ "$DRY_RUN" = true ]; then
        log_warning "Running in dry-run mode. No changes will be made."
        echo
    fi

    check_requirements
    create_directories
    install_plugins
    install_font
    link_config_files
    install_nvchad
    check_nvchad

    echo
    log_success "Setup completed successfully!"
    log_info "You may need to restart your shell or run 'source ~/.zshrc' to apply changes."
    log_info "Zinit will automatically install ZSH plugins on first shell launch."
    log_info "To activate tmux plugins, start tmux and press prefix + I (capital I)."
}

# Run the main function
main

exit 0
