#!/bin/bash
#
# Dotfiles update
# Pull this clone, relink configs that no longer point here, then refresh
# only the plugin managers the active profile uses.
#
#   minimal  Zinit
#   full     Zinit, TPM, and Neovim (Lazy)
#   claude   no plugin managers
#
# The clone is the directory that contains this script, not a fixed path.
# ~/Developer/src/dots is only the default for the `dots` shortcut.
#

set -euo pipefail

# Color definitions (same convention as setup.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
PROFILES=()
PROFILE_FROM_FLAG=false
LINK_CHANGES=0
REFRESH_FAILURES=0

log_info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$1"
}

log_success() {
    printf '%b[SUCCESS]%b %s\n' "$GREEN" "$NC" "$1"
}

log_warning() {
    printf '%b[WARNING]%b %s\n' "$YELLOW" "$NC" "$1"
}

log_error() {
    printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Resolve this file's directory even if the script itself is a symlink.
# Does not change the caller's working directory.
resolve_script_dir() {
    local source_script dir target resolved hops
    source_script="${BASH_SOURCE[0]}"
    hops=0
    while [ -L "$source_script" ]; do
        hops=$((hops + 1))
        if [ "$hops" -gt 20 ]; then
            log_error "Too many symlinks while resolving $0"
            return 1
        fi
        dir=$(cd -P "$(dirname "$source_script")" && pwd) || return 1
        target=$(readlink "$source_script") || return 1
        case "$target" in
            /*) source_script=$target ;;
            *) source_script="$dir/$target" ;;
        esac
    done
    resolved=$(cd -P "$(dirname "$source_script")" && pwd) || return 1
    printf '%s\n' "$resolved"
}

print_usage() {
    printf '%bUsage:%b %s [options]\n' "$BOLD" "$NC" "$0"
    echo
    echo "Pull this clone, relink configs that are missing or point elsewhere,"
    echo "then refresh only the plugin managers the active profile uses."
    echo
    echo "Run it from any working directory. The clone is the directory that"
    echo "contains this script, not ~/Developer/src/dots."
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --dry-run           Show what would be done without making changes"
    echo "  -p, --profile <name>    Profile to update (repeatable). Default: detect"
    echo
    echo "Profiles (same names as ./setup.sh):"
    echo "  minimal   Refresh Zinit only. Does not refresh TPM or Neovim."
    echo "  claude    Relink Claude config. No plugin managers."
    echo "  full      Includes minimal and claude, and refreshes TPM and Neovim."
    echo
    echo "With no --profile, links under \$HOME decide the profile. If nothing"
    echo "is linked yet, the default is minimal (the same default as ./setup.sh)."
    echo
    printf 'The dots shortcut defaults to %s when no clone is linked.\n' "$(dots_default_root)"
    echo
    echo "This script never reads from the terminal. A non-TTY run cannot hang"
    echo "on a prompt. git is told not to ask for credentials when stdin is not a TTY."
}

# full includes every other profile, matching setup.sh profile_active.
profile_active() {
    local target="$1"
    local p
    for p in "${PROFILES[@]}"; do
        if [[ "$p" == "full" || "$p" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

# True when $1 is a symlink to this clone's $2, or a broken link that used
# to point at that repo-relative path (the clone was moved).
points_at_rel() {
    local path="$1"
    local rel="$2"
    local target
    if [ ! -L "$path" ]; then
        return 1
    fi
    target=$(readlink "$path") || return 1
    if [ "$target" = "$ROOT/$rel" ]; then
        return 0
    fi
    case "$target" in
        */"$rel")
            if [ -e "$path" ]; then
                return 1
            fi
            return 0
            ;;
    esac
    return 1
}

detect_profiles() {
    local found_full=false
    local found_minimal=false
    local found_claude=false

    if points_at_rel "$HOME/.vimrc" "vim/vimrc" \
        || points_at_rel "$HOME/.tmux.conf" "tmux/tmux.conf" \
        || points_at_rel "$HOME/.config/nvim" "nvim" \
        || points_at_rel "$HOME/.config/opencode/opencode.json" "opencode/opencode.json"; then
        found_full=true
    fi

    if points_at_rel "$HOME/.zshrc" "zsh/zshrc" \
        || points_at_rel "$HOME/.zshenv" "zsh/zshenv" \
        || points_at_rel "$HOME/.config/starship.toml" "starship/starship.toml" \
        || points_at_rel "$HOME/.gitconfig" "git/gitconfig"; then
        found_minimal=true
    fi

    if points_at_rel "$HOME/.claude/hooks" "claude/hooks" \
        || points_at_rel "$HOME/.claude/scripts" "claude/scripts" \
        || points_at_rel "$HOME/.claude/CLAUDE.md" "claude/CLAUDE.md"; then
        found_claude=true
    fi

    if [ "$found_full" = true ]; then
        PROFILES=("full")
        return 0
    fi

    PROFILES=()
    if [ "$found_minimal" = true ]; then
        PROFILES+=("minimal")
    fi
    if [ "$found_claude" = true ]; then
        PROFILES+=("claude")
    fi

    if [ ${#PROFILES[@]} -eq 0 ]; then
        PROFILES=("minimal")
        log_info "No linked profile found; defaulting to minimal."
    fi
}

configure_noninteractive_git() {
    if [ -t 0 ]; then
        return 0
    fi
    # No `read`, no credential prompt, no ssh passphrase prompt, no editor.
    log_info "No terminal on stdin; git and plugin refresh will not prompt."
    export GIT_TERMINAL_PROMPT=0
    export GIT_EDITOR=true
    export GIT_PAGER=cat
    if [ -z "${GIT_SSH_COMMAND:-}" ]; then
        export GIT_SSH_COMMAND="ssh -o BatchMode=yes"
    fi
}

pull_clone() {
    if [ "$DRY_RUN" = true ]; then
        log_info "Would run: git -C \"$ROOT\" pull --ff-only"
        return 0
    fi

    if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not a git repository: $ROOT"
        return 1
    fi

    log_info "Pulling $ROOT"
    if ! git -C "$ROOT" pull --ff-only; then
        log_error "git pull --ff-only failed in $ROOT"
        return 1
    fi
    log_success "Clone is up to date."
}

add_link() {
    local rel="$1"
    local dest="$2"
    local source_path="$ROOT/$rel"
    if [ -e "$source_path" ]; then
        LINK_PAIRS+=("${source_path}|${dest}")
    fi
}

collect_links() {
    LINK_PAIRS=()

    if profile_active "minimal"; then
        add_link "zsh/zshrc" "$HOME/.zshrc"
        add_link "zsh/zshenv" "$HOME/.zshenv"
        add_link "starship/starship.toml" "$HOME/.config/starship.toml"
        add_link "git/gitconfig" "$HOME/.gitconfig"
        add_link "git/gitignore_global" "$HOME/.gitignore_global"
        add_link "zsh/aliases" "$HOME/.config/zsh/aliases"
        add_link "zsh/hosts" "$HOME/.config/zsh/hosts"
        add_link "zsh/profile-macos" "$HOME/.config/zsh/profile-macos"
        add_link "zsh/profile-linux" "$HOME/.config/zsh/profile-linux"
        add_link "zsh/profile-work" "$HOME/.config/zsh/profile-work"
        add_link "ghostty" "$HOME/.config/ghostty"
    fi

    if profile_active "full"; then
        add_link "vim/vimrc" "$HOME/.vimrc"
        add_link "tmux/tmux.conf" "$HOME/.tmux.conf"
        add_link "opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
        add_link "nvim" "$HOME/.config/nvim"
    fi

    if profile_active "claude"; then
        add_link "claude/hooks" "$HOME/.claude/hooks"
        add_link "claude/scripts" "$HOME/.claude/scripts"
        add_link "claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    fi
}

# ~/.claude/skills and commands are real directories of per-item symlinks.
prepare_real_dir() {
    local dir="$1"
    if [ -L "$dir" ]; then
        LINK_CHANGES=$((LINK_CHANGES + 1))
        if [ "$DRY_RUN" = true ]; then
            log_info "Would replace symlink with directory: $dir"
            return 0
        fi
        rm -f "$dir"
        mkdir -p "$dir"
        log_info "Replaced symlink with directory: $dir"
        return 0
    fi
    if [ ! -d "$dir" ]; then
        LINK_CHANGES=$((LINK_CHANGES + 1))
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create directory: $dir"
            return 0
        fi
        mkdir -p "$dir"
        log_success "Created directory: $dir"
    fi
}

ensure_link() {
    local source_path="$1"
    local target_path="$2"
    local current parent

    if [ -L "$target_path" ]; then
        current=$(readlink "$target_path")
        if [ "$current" = "$source_path" ] && [ -e "$target_path" ]; then
            return 0
        fi
        LINK_CHANGES=$((LINK_CHANGES + 1))
        if [ "$DRY_RUN" = true ]; then
            log_info "Would relink: $source_path -> $target_path"
            return 0
        fi
        rm -f "$target_path"
    elif [ -e "$target_path" ]; then
        log_warning "Leaving existing non-symlink in place: $target_path"
        return 0
    else
        LINK_CHANGES=$((LINK_CHANGES + 1))
        if [ "$DRY_RUN" = true ]; then
            log_info "Would link: $source_path -> $target_path"
            return 0
        fi
    fi

    parent=$(dirname "$target_path")
    if [ ! -d "$parent" ]; then
        mkdir -p "$parent"
    fi
    if ln -sf "$source_path" "$target_path"; then
        log_success "Linked: $source_path -> $target_path"
    else
        log_error "Failed to link: $source_path -> $target_path"
        return 1
    fi
}

add_child_links() {
    local source_dir="$1"
    local dest_dir="$2"
    local child name
    if [ ! -d "$source_dir" ]; then
        return 0
    fi
    for child in "$source_dir"/*; do
        if [ ! -e "$child" ]; then
            continue
        fi
        name=$(basename "$child")
        LINK_PAIRS+=("${child}|${dest_dir}/${name}")
    done
}

relink_configs() {
    local pair source_path target_path
    local skills_src commands_src

    collect_links

    if profile_active "claude"; then
        prepare_real_dir "$HOME/.claude"
        prepare_real_dir "$HOME/.claude/skills"
        prepare_real_dir "$HOME/.claude/commands"
        skills_src="$ROOT/llm/skills"
        commands_src="$ROOT/llm/commands"
        add_child_links "$skills_src" "$HOME/.claude/skills"
        add_child_links "$commands_src" "$HOME/.claude/commands"
    fi

    if [ ${#LINK_PAIRS[@]} -eq 0 ]; then
        log_info "No config files to link for this profile."
        return 0
    fi

    for pair in "${LINK_PAIRS[@]}"; do
        source_path="${pair%%|*}"
        target_path="${pair#*|}"
        if ! ensure_link "$source_path" "$target_path"; then
            return 1
        fi
    done

    if [ "$LINK_CHANGES" -eq 0 ]; then
        log_info "Config links already point at this clone."
    elif [ "$DRY_RUN" = true ]; then
        log_info "Would change $LINK_CHANGES link(s)."
    fi
}

refresh_zinit() {
    local zinit_zsh
    zinit_zsh="${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}/zinit.zsh"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would refresh Zinit (self-update, then update --all)."
        return 0
    fi

    if [ ! -f "$zinit_zsh" ]; then
        log_warning "Zinit is not installed; skipping zsh plugin refresh."
        return 0
    fi

    if ! command_exists zsh; then
        log_warning "zsh is not installed; skipping Zinit refresh."
        return 0
    fi

    log_info "Refreshing Zinit and zsh plugins..."
    # -f skips rc files. stdin is /dev/null so a prompt cannot block.
    if ! zsh -f -c 'source "$1" && zinit self-update && zinit update --all' zsh "$zinit_zsh" </dev/null; then
        log_warning "Zinit refresh failed."
        return 1
    fi
    log_success "Refreshed Zinit."
}

refresh_tpm() {
    local tpm_dir updater
    tpm_dir="$HOME/.tmux/plugins/tpm"
    updater="$tpm_dir/bin/update_plugins"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would refresh TPM (git pull, then update_plugins all)."
        return 0
    fi

    if [ ! -x "$updater" ]; then
        log_warning "TPM is not installed; skipping tmux plugin refresh."
        return 0
    fi

    log_info "Refreshing TPM..."
    if ! git -C "$tpm_dir" pull --ff-only; then
        log_warning "Could not fast-forward TPM; continuing with installed plugins."
    fi

    if ! "$updater" all </dev/null; then
        log_warning "TPM plugin refresh failed."
        return 1
    fi
    log_success "Refreshed TPM plugins."
}

refresh_neovim() {
    if [ "$DRY_RUN" = true ]; then
        log_info "Would refresh Neovim plugins: nvim --headless \"+Lazy! sync\" +qa"
        return 0
    fi

    if ! command_exists nvim; then
        log_warning "nvim is not installed; skipping Neovim plugin refresh."
        return 0
    fi

    if [ ! -e "$HOME/.config/nvim/init.lua" ]; then
        log_warning "Neovim config is not linked; skipping Neovim plugin refresh."
        return 0
    fi

    log_info "Refreshing Neovim plugins..."
    if ! nvim --headless "+Lazy! sync" +qa </dev/null; then
        log_warning "Neovim plugin refresh failed."
        return 1
    fi
    log_success "Refreshed Neovim plugins."
}

refresh_plugins() {
    # minimal (and full, which includes minimal) refreshes Zinit only among
    # shell plugin managers. TPM and Neovim run only for full.
    if profile_active "minimal"; then
        if ! refresh_zinit; then
            REFRESH_FAILURES=$((REFRESH_FAILURES + 1))
        fi
    else
        log_info "Skipping Zinit; the active profile does not use it."
    fi

    if profile_active "full"; then
        if ! refresh_tpm; then
            REFRESH_FAILURES=$((REFRESH_FAILURES + 1))
        fi
        if ! refresh_neovim; then
            REFRESH_FAILURES=$((REFRESH_FAILURES + 1))
        fi
    else
        log_info "Skipping TPM and Neovim; the active profile does not use them."
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -p|--profile)
                if [[ -z "${2:-}" ]]; then
                    log_error "--profile requires a value (minimal, claude, full)"
                    print_usage
                    exit 1
                fi
                case $2 in
                    minimal|claude|full)
                        PROFILES+=("$2")
                        PROFILE_FROM_FLAG=true
                        ;;
                    *)
                        log_error "Unknown profile: $2 (valid: minimal, claude, full)"
                        print_usage
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

main() {
    printf '%bDotfiles Update%b\n' "$BOLD" "$NC"
    echo "===================="
    echo

    if [ "$DRY_RUN" = true ]; then
        log_warning "Running in dry-run mode. No changes will be made."
        echo
    fi

    configure_noninteractive_git

    if [ "$PROFILE_FROM_FLAG" = false ]; then
        detect_profiles
    fi

    log_info "Clone: $ROOT"
    log_info "Active profiles: ${PROFILES[*]}"
    echo

    pull_clone
    echo
    relink_configs
    echo
    refresh_plugins

    echo
    if [ "$DRY_RUN" = true ]; then
        log_success "Dry run finished. No changes were made."
    elif [ "$REFRESH_FAILURES" -gt 0 ]; then
        log_error "Update finished with $REFRESH_FAILURES plugin refresh failure(s)."
        return 1
    else
        log_success "Update finished."
    fi
}

ROOT=$(resolve_script_dir) || exit 1
if [ -z "${ROOT}" ]; then
    log_error "Could not resolve the directory of $0"
    exit 1
fi

if [ -f "$ROOT/lib/dots-root.sh" ]; then
    # shellcheck source=lib/dots-root.sh
    source "$ROOT/lib/dots-root.sh"
else
    dots_default_root() {
        printf '%s\n' "${HOME}/Developer/src/dots"
    }
fi

parse_args "$@"
main
