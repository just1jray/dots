#!/bin/bash
# Extract testable functions from setup.sh for unit testing
# This file sources setup.sh in a controlled way

# Get the absolute path to setup.sh
SETUP_SCRIPT="${PROJECT_ROOT}/setup.sh"

# Color definitions (copied from setup.sh to avoid sourcing the whole script)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Default flag values
FORCE=false
DRY_RUN=false
SKIP_PLUGINS=false
CHECK_NVCHAD_ONLY=false
INSTALL_FONT=false

# Configuration (use TEST_TEMP_DIR if set, otherwise use defaults)
if [[ -n "$TEST_TEMP_DIR" ]]; then
    ZSH_PLUGINS_DIR="$TEST_TEMP_DIR/.config/zsh/plugins"
    DEV_DIR="$TEST_TEMP_DIR/Developer/src"
    TMUX_PLUGINS_DIR="$TEST_TEMP_DIR/.tmux/plugins"
    TMUX_PLUGIN_RESURRECT_DIR="$TEST_TEMP_DIR/.tmux/plugins/resurrect"
else
    ZSH_PLUGINS_DIR="$HOME/.config/zsh/plugins"
    DEV_DIR="$HOME/Developer/src"
    TMUX_PLUGINS_DIR="$HOME/.tmux/plugins"
    TMUX_PLUGIN_RESURRECT_DIR="$HOME/.tmux/plugins/resurrect"
fi

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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

# Parse command line arguments (for testing argument parsing)
parse_args() {
    FORCE=false
    DRY_RUN=false
    SKIP_PLUGINS=false
    CHECK_NVCHAD_ONLY=false
    INSTALL_FONT=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                return 0
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
                return 1
                ;;
        esac
    done
}
