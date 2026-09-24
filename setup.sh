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
# Physical path so links match what update.sh resolves with `cd -P`.
REPO_DIR=$(pwd -P)

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
    echo "  ai        AI tools: claude code config, llm skills/commands, cursor cli"
    echo "  full      Everything: minimal plus vim, tmux, Neovim, opencode, and a Nerd Font"
    echo
    echo "Profiles are composable. Combine them with multiple --profile flags:"
    echo "  $0 --profile minimal --profile ai"
    echo
    echo "Profile packages (separate from the Brewfile):"
    echo "  minimal   zsh, git, and starship"
    echo "  full      also neovim, tmux, and JetBrains Mono Nerd Font"
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
        directories+=("$TMUX_PLUGIN_RESURRECT_DIR")
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
        install_tmux_plugins
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

# Merge portable hook stanzas into ~/.claude/settings.json.
#
# settings.json stays machine-local (it holds model, statusLine, plugins and
# other per-machine choices), so the hook wiring cannot simply be symlinked.
# Instead the stanzas live in claude/settings.hooks.json and are merged in
# here. The merge is idempotent: entries are keyed on their command string,
# so re-running setup.sh never duplicates a hook.
merge_claude_hooks() {
    local fragment="$1"
    local settings="$2"
    local hooks_dir="$3"

    [ -f "$fragment" ] || return 0

    if ! command_exists jq; then
        log_warning "jq not found; skipping Claude hook merge (hooks are installed but not registered)"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would merge hook config from $fragment into $settings"
        return 0
    fi

    [ -f "$settings" ] || echo '{}' >"$settings"

    if ! jq -e . "$settings" >/dev/null 2>&1; then
        log_error "$settings is not valid JSON; skipping hook merge"
        return 1
    fi

    local resolved merged
    resolved=$(mktemp) || return 1
    merged=$(mktemp) || { rm -f "$resolved"; return 1; }

    sed "s|{{CLAUDE_HOOKS}}|$hooks_dir|g" "$fragment" >"$resolved"

    if jq -s '
        .[0] as $cur
        | .[1] as $add
        | reduce ($add.hooks | to_entries[]) as $evt
            ($cur;
             .hooks = (.hooks // {})
             | .hooks[$evt.key] = (
                 (.hooks[$evt.key] // []) as $existing
                 | ($existing | map(.hooks[].command)) as $have
                 | $existing + (
                     $evt.value
                     | map(select(([.hooks[].command] - $have) | length > 0))
                   )
               ))
    ' "$settings" "$resolved" >"$merged" && [ -s "$merged" ]; then
        if ! cmp -s "$settings" "$merged"; then
            backup_config_file "$settings" >/dev/null 2>&1 || true
            mv "$merged" "$settings"
            log_success "Merged Claude hook config into $settings"
        else
            log_info "Claude hook config already present in $settings"
            rm -f "$merged"
        fi
    else
        log_error "Failed to merge hook config into $settings"
        rm -f "$merged"
    fi

    rm -f "$resolved"
}

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

    local config_files=()

    # minimal profile: zsh, starship, git
    if profile_active "minimal"; then
        config_files+=(
            "zsh/zshrc|$HOME/.zshrc"
            "zsh/zshenv|$HOME/.zshenv"
            "starship/starship.toml|$HOME/.config/starship.toml"
            "git/gitconfig|$HOME/.gitconfig"
            "git/gitignore_global|$HOME/.gitignore_global"
            "lib/dots-root.sh|$HOME/.config/zsh/dots-root.sh"
        )

        # Add optional zsh files if they exist
        if [ -f "$REPO_DIR/zsh/aliases" ]; then
            config_files+=("zsh/aliases|$HOME/.config/zsh/aliases")
        fi
        if [ -f "$REPO_DIR/zsh/hosts" ]; then
            config_files+=("zsh/hosts|$HOME/.config/zsh/hosts")
        fi
        if [ -f "$REPO_DIR/zsh/profile-macos" ]; then
            config_files+=("zsh/profile-macos|$HOME/.config/zsh/profile-macos")
        fi
        if [ -f "$REPO_DIR/zsh/profile-linux" ]; then
            config_files+=("zsh/profile-linux|$HOME/.config/zsh/profile-linux")
        fi
        if [ -f "$REPO_DIR/zsh/profile-work" ]; then
            config_files+=("zsh/profile-work|$HOME/.config/zsh/profile-work")
        fi
    fi

    # full profile: vim, tmux, opencode, btop
    if profile_active "full"; then
        config_files+=(
            "vim/vimrc|$HOME/.vimrc"
            "tmux/tmux.conf|$HOME/.tmux.conf"
            "opencode/opencode.json|$HOME/.config/opencode/opencode.json"
            "btop/btop.conf|$HOME/.config/btop/btop.conf"
            "btop/themes/catppuccin_mocha.theme|$HOME/.config/btop/themes/catppuccin_mocha.theme"
        )
    fi

    # bash 3.2 (macOS) treats "${arr[@]}" on an empty array as unbound under
    # `set -u`, and --profile ai alone leaves this list empty.
    for config in ${config_files[@]+"${config_files[@]}"}; do
        IFS='|' read -r source_file target_file <<< "$config"
        source_path="$REPO_DIR/$source_file"

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

    # Link NVChad config directory (full profile only)
    local nvim_source
    nvim_source="$REPO_DIR/nvim"
    local nvim_target="$HOME/.config/nvim"

    if profile_active "full"; then
        if [ -d "$nvim_source" ]; then
            if ! backup_config_file "$nvim_target"; then
                log_error "Backup failed for $nvim_target, skipping to prevent data loss"
                return 1
            fi

            if [ "$DRY_RUN" = true ]; then
                log_info "Would link directory: $nvim_source → $nvim_target"
            else
                if ln -sf "$nvim_source" "$nvim_target"; then
                    if [ -L "$nvim_target" ] && [ -e "$nvim_target" ]; then
                        log_success "Linked NVChad config: $nvim_source → $nvim_target"
                    else
                        log_error "Symlink created but target is broken: $nvim_target"
                        log_error "Source may not exist: $nvim_source"
                        rm -f "$nvim_target"
                    fi
                else
                    log_error "Failed to create symlink: $nvim_source → $nvim_target"
                fi
            fi
        else
            log_warning "NVChad config directory does not exist: $nvim_source"
        fi
    fi

    # Link Ghostty config directory (minimal profile)
    local ghostty_source
    ghostty_source="$REPO_DIR/ghostty"
    local ghostty_target="$HOME/.config/ghostty"

    if profile_active "minimal"; then
        if [ -d "$ghostty_source" ]; then
            if ! backup_config_file "$ghostty_target"; then
                log_error "Backup failed for $ghostty_target, skipping"
            else
                if [ "$DRY_RUN" = true ]; then
                    log_info "Would link directory: $ghostty_source → $ghostty_target"
                else
                    if ln -sf "$ghostty_source" "$ghostty_target"; then
                        if [ -L "$ghostty_target" ] && [ -e "$ghostty_target" ]; then
                            log_success "Linked Ghostty config: $ghostty_source → $ghostty_target"
                        else
                            log_error "Symlink created but target is broken: $ghostty_target"
                            rm -f "$ghostty_target"
                        fi
                    else
                        log_error "Failed to create symlink: $ghostty_source → $ghostty_target"
                    fi
                fi
            fi
        else
            log_warning "Ghostty config directory does not exist: $ghostty_source"
        fi

        # cmd chords and macos-* keys live in a file Ghostty loads only on Darwin.
        if [ "$(uname)" = "Darwin" ]; then
            link_ghostty_macos
        fi
    fi

    # Link Claude Code config files (ai profile)
    local claude_source
    claude_source="$REPO_DIR/claude"
    local claude_target="$HOME/.claude"

    if profile_active "ai"; then
    if [ -d "$claude_source" ]; then
        # Create ~/.claude directory if it doesn't exist (Claude Code manages ephemeral data here)
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create directory: $claude_target"
        else
            mkdir -p "$claude_target"
        fi

        # Symlink individual portable config files/directories
        local claude_items=("hooks" "scripts" "CLAUDE.md")
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

        # Register the portable hooks in the machine-local settings.json
        merge_claude_hooks \
            "$claude_source/settings.hooks.json" \
            "$claude_target/settings.json" \
            "$claude_target/hooks" ||
            log_warning "Claude hooks were not registered; re-run setup after fixing settings.json"

        # Link LLM skills and commands into real directories
        # Using real directories allows externally installed skills/commands to coexist
        # without polluting the dotfiles repo
        local llm_source
        llm_source="$REPO_DIR/llm"

        if [ -d "$llm_source" ]; then
            # Set up ~/.claude/skills/ as a real directory
            local skills_target="$claude_target/skills"
            if [ -L "$skills_target" ]; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "Would remove skills symlink and create directory: $skills_target"
                else
                    rm -f "$skills_target"
                    log_info "Removed old skills symlink: $skills_target"
                    mkdir -p "$skills_target"
                fi
            elif [ ! -d "$skills_target" ]; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "Would create directory: $skills_target"
                else
                    mkdir -p "$skills_target"
                fi
            fi

            # Symlink each skill from llm/skills/ into ~/.claude/skills/
            for skill_dir in "$llm_source"/skills/*/; do
                [ -d "$skill_dir" ] || continue
                local skill_name
                skill_name=$(basename "$skill_dir")
                local skill_source="${skill_dir%/}"
                local skill_target="$skills_target/$skill_name"

                if ! backup_config_file "$skill_target"; then
                    log_error "Backup failed for $skill_target, skipping"
                    continue
                fi

                if [ "$DRY_RUN" = true ]; then
                    log_info "Would link skill: $skill_source → $skill_target"
                else
                    if ln -sf "$skill_source" "$skill_target"; then
                        if [ -L "$skill_target" ] && [ -e "$skill_target" ]; then
                            log_success "Linked skill: $skill_name → $skill_target"
                        else
                            log_error "Symlink created but target is broken: $skill_target"
                            rm -f "$skill_target"
                        fi
                    else
                        log_error "Failed to create symlink: $skill_source → $skill_target"
                    fi
                fi
            done

            # Set up ~/.claude/commands/ as a real directory
            local commands_target="$claude_target/commands"
            if [ -L "$commands_target" ]; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "Would remove commands symlink and create directory: $commands_target"
                else
                    rm -f "$commands_target"
                    log_info "Removed old commands symlink: $commands_target"
                    mkdir -p "$commands_target"
                fi
            elif [ ! -d "$commands_target" ]; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "Would create directory: $commands_target"
                else
                    mkdir -p "$commands_target"
                fi
            fi

            # Symlink each command from llm/commands/ into ~/.claude/commands/
            for cmd_file in "$llm_source"/commands/*; do
                [ -e "$cmd_file" ] || continue
                local cmd_name
                cmd_name=$(basename "$cmd_file")
                local cmd_target="$commands_target/$cmd_name"

                if ! backup_config_file "$cmd_target"; then
                    log_error "Backup failed for $cmd_target, skipping"
                    continue
                fi

                if [ "$DRY_RUN" = true ]; then
                    log_info "Would link command: $cmd_file → $cmd_target"
                else
                    if ln -sf "$cmd_file" "$cmd_target"; then
                        if [ -L "$cmd_target" ] && [ -e "$cmd_target" ]; then
                            log_success "Linked command: $cmd_name → $cmd_target"
                        else
                            log_error "Symlink created but target is broken: $cmd_target"
                            rm -f "$cmd_target"
                        fi
                    else
                        log_error "Failed to create symlink: $cmd_file → $cmd_target"
                    fi
                fi
            done
        fi
    else
        log_warning "Claude Code config directory does not exist: $claude_source"
    fi
    fi
}

# Merge portable Cursor CLI preferences into ~/.cursor/cli-config.json.
# Cursor rewrites that file with auth and cache data, so it is not symlinked.
# Tracked keys overwrite; keys absent from the repo file are left in place.
install_cursor_cli_config() {
    if ! profile_active "ai"; then
        return
    fi

    local merge_helper="$REPO_DIR/lib/cursor-config.sh"
    if [ ! -f "$merge_helper" ]; then
        log_error "Cursor CLI merge helper not found: $merge_helper"
        return
    fi

    # shellcheck source=lib/cursor-config.sh
    source "$merge_helper"
    if ! merge_cursor_cli_config \
        "$REPO_DIR/cursor/cli-config.json" \
        "$HOME/.cursor/cli-config.json" \
        "$DRY_RUN"; then
        log_warning "Cursor CLI preferences were not changed."
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

    if ! "${sudo_cmd[@]}" apt-get update; then
        log_warning "apt-get update failed. Continuing with the package lists already on disk."
    fi

    for pkg in "${requested[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            available+=("$pkg")
        else
            unavailable+=("$pkg")
        fi
    done

    for pkg in "${available[@]}"; do
        if "${sudo_cmd[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
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

# minimal: zsh, git, starship. full also: neovim, tmux.
# Font for full is install_font, not a package-manager formula.
# pyenv, nvm, Bun, Claude, and Ghostty are not in this list.
install_profile_packages() {
    local packages=()
    local os

    if profile_active "minimal"; then
        packages+=(zsh git starship)
    fi
    if profile_active "full"; then
        packages+=(neovim tmux)
    fi

    if [ ${#packages[@]} -eq 0 ]; then
        log_info "Active profile does not install packages. pyenv, nvm, Bun, Claude, and Ghostty stay optional."
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

link_ghostty_macos() {
    local source_path
    local target_dir
    local target_path
    source_path="$REPO_DIR/ghostty/macos"
    target_dir="${HOME}/Library/Application Support/com.mitchellh.ghostty"
    target_path="${target_dir}/config"

    if [ ! -f "$source_path" ]; then
        log_warning "macOS Ghostty config does not exist: $source_path"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Would link macOS Ghostty keys: $source_path → $target_path"
        return 0
    fi

    mkdir -p "$target_dir"
    if ! backup_config_file "$target_path"; then
        log_error "Backup failed for $target_path, skipping macOS Ghostty keys"
        return 0
    fi
    if ln -sf "$source_path" "$target_path"; then
        log_success "Linked macOS Ghostty keys: $source_path → $target_path"
    else
        log_error "Failed to link macOS Ghostty keys"
    fi
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

    brewfile="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Brewfile"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would install Homebrew packages from $brewfile ($brew_bin bundle install)"
        return 0
    fi

    log_info "Installing Homebrew packages from Brewfile..."
    if "$brew_bin" bundle install --file="$brewfile"; then
        log_success "Homebrew packages installed."
    else
        log_error "brew bundle failed. Re-run '$brew_bin bundle --file=$brewfile' to retry."
    fi
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
    else
        log_success "Setup completed successfully!"
    fi
    if profile_active "minimal"; then
        log_info "You may need to restart your shell or run 'source ~/.zshrc' to apply changes."
        log_info "Zinit will automatically install ZSH plugins on first shell launch."
    fi
    if profile_active "full"; then
        log_info "To activate tmux plugins, start tmux and press prefix + I (capital I)."
    fi
    if [ "$PACKAGE_INSTALL_FAILED" = true ]; then
        return 1
    fi
}

# Run the main function
main

exit 0
