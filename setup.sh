#!/bin/bash
#
# Dotfiles Setup Script
# This script sets up configuration files and plugins for zsh, vim, nvim, and tmux
# 

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
ZSH_PLUGINS_DIR="$HOME/.config/zsh/plugins"
NVIM_DIR="$HOME/.config/nvim"
NVIM_THEMES_DIR="$NVIM_DIR/pack/themes/start"
DEV_DIR="$HOME/Developer/src"
TMUX_PLUGINS_DIR="$HOME/.tmux/plugins"
TMUX_PLUGIN_RESURRECT_DIR="$HOME/.tmux/plugins/resurrect"

# Print usage information
print_usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Force overwrite of existing config files without backup"
    echo "  -n, --dry-run  Show what would be done without making changes"
    echo "  -s, --skip-plugins  Skip plugin installation"
    echo
    echo "This script sets up dotfiles for zsh, vim, nvim, and tmux."
    echo "It creates necessary directories, installs plugins, and symlinks config files."
}

# Parse command line arguments
FORCE=false
DRY_RUN=false
SKIP_PLUGINS=false

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
        "$NVIM_DIR"
        "$NVIM_THEMES_DIR"
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
    
    # Define ZSH and Neovim plugins to install
    local plugins=(
        "https://github.com/romkatv/powerlevel10k.git|$ZSH_PLUGINS_DIR/powerlevel10k"
        "https://github.com/marlonrichert/zsh-autocomplete.git|$ZSH_PLUGINS_DIR/zsh-autocomplete"
        "https://github.com/zsh-users/zsh-autosuggestions.git|$ZSH_PLUGINS_DIR/zsh-autosuggestions"
        "https://github.com/zsh-users/zsh-syntax-highlighting.git|$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
        "https://github.com/folke/tokyonight.nvim.git|$NVIM_THEMES_DIR/tokyonight.nvim"
    )
    
    for plugin in "${plugins[@]}"; do
        IFS='|' read -r repo_url install_dir <<< "$plugin"
        plugin_name=$(basename "$install_dir")
        
        if [ ! -d "$install_dir" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would install plugin: $plugin_name"
            else
                log_info "Installing plugin: $plugin_name"
                if git clone --depth=1 "$repo_url" "$install_dir"; then
                    log_success "Installed plugin: $plugin_name"
                    
                    # Special case for powerlevel10k
                    if [[ "$plugin_name" == "powerlevel10k" ]]; then
                        # Check if the line already exists in .zshrc
                        if ! grep -q "source ~/.config/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme" "$HOME/.zshrc" 2>/dev/null; then
                            log_info "Adding powerlevel10k to .zshrc"
                            echo 'source ~/.config/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme' >> "$HOME/.zshrc"
                        fi
                    fi
                else
                    log_error "Failed to install plugin: $plugin_name"
                fi
            fi
        else
            log_info "Plugin already installed: $plugin_name"
        fi
    done
    
    # Install Tmux Plugin Manager and plugins
    install_tmux_plugins
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
                log_error "Failed to install Tmux Plugin Manager"
                return
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
                fi
            fi
        else
            log_info "Tmux plugin already installed: $plugin_name"
        fi
    done
    
    # Provide instructions for installing plugins via tpm
    if [ "$DRY_RUN" = false ]; then
        log_info "Tmux plugins installed. To activate them:"
        log_info "1. Start tmux"
        log_info "2. Press prefix + I (capital I) to install plugins"
    fi
}

# Backup existing config file
backup_config_file() {
    local file="$1"
    
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would remove existing file without backup: $file"
            else
                rm -f "$file"
                log_warning "Removed existing file without backup: $file"
            fi
        else
            local backup_file="${file}.old_$(date +%F_%H-%M-%S)"
            if [ "$DRY_RUN" = true ]; then
                log_info "Would backup file: $file → $backup_file"
            else
                mv -v "$file" "$backup_file"
                log_success "Backed up file: $file → $backup_file"
            fi
        fi
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
        "vim/vimrc|$HOME/.vimrc"
        "nvim/init.vim|$NVIM_DIR/init.vim"
        "tmux/tmux.conf|$HOME/.tmux.conf"
    )

    # Add aliases file if it exists
    if [ -f "$(pwd)/zsh/aliases" ]; then
        config_files+=("zsh/aliases|$HOME/.config/zsh/aliases")
    fi

    # Add hosts file if it exists
    if [ -f "$(pwd)/zsh/hosts" ]; then
        config_files+=("zsh/hosts|$HOME/.config/zsh/hosts")
    fi
    
    for config in "${config_files[@]}"; do
        IFS='|' read -r source_file target_file <<< "$config"
        source_path="$(pwd)/$source_file"
        
        if [ ! -f "$source_path" ]; then
            log_warning "Source file does not exist: $source_path"
            continue
        fi
        
        backup_config_file "$target_file"
        
        if [ "$DRY_RUN" = true ]; then
            log_info "Would link file: $source_path → $target_file"
        else
            if ln -sf "$source_path" "$target_file"; then
                log_success "Linked file: $source_path → $target_file"
            else
                log_error "Failed to link file: $source_path → $target_file"
            fi
        fi
    done
}

# Main function
main() {
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
    link_config_files
    
    echo
    log_success "Setup completed successfully!"
    log_info "You may need to restart your shell or run 'source ~/.zshrc' to apply changes."
    log_info "To activate tmux plugins, start tmux and press prefix + I (capital I)."
}

# Run the main function
main

exit 0
