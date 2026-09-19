# Resolve the dotfiles clone for the `dots` shortcut.
# Shared by bash (update.sh) and zsh (zsh/aliases).
# Do not enable set -e here: interactive zsh sources this file.
#
# Precedence:
#   1. $DOTS_DIR
#   2. symlink target of ~/.zshrc (<clone>/zsh/zshrc)
#   3. symlink target of ~/.config/zsh/aliases (<clone>/zsh/aliases)
#   4. $HOME/Developer/src/dots

dots_default_root() {
    printf '%s\n' "${HOME}/Developer/src/dots"
}

# Print the clone root implied by a symlink, or nothing.
# $1 = symlink path, $2 = directory levels from the target up to the clone.
_dots_root_from_link() {
    local path="$1"
    local depth="$2"
    local target
    local i

    if [ ! -L "$path" ]; then
        return 0
    fi

    target=$(readlink "$path") || return 0
    case "$target" in
        /*) ;;
        *) target="$(dirname "$path")/$target" ;;
    esac

    i=0
    while [ "$i" -lt "$depth" ]; do
        target=$(dirname "$target")
        i=$((i + 1))
    done
    printf '%s\n' "$target"
}

dots_root() {
    local from_link

    if [ -n "${DOTS_DIR:-}" ]; then
        printf '%s\n' "$DOTS_DIR"
        return 0
    fi

    # ~/.zshrc -> <clone>/zsh/zshrc
    from_link=$(_dots_root_from_link "$HOME/.zshrc" 2)
    if [ -n "$from_link" ]; then
        printf '%s\n' "$from_link"
        return 0
    fi

    # ~/.config/zsh/aliases -> <clone>/zsh/aliases
    from_link=$(_dots_root_from_link "$HOME/.config/zsh/aliases" 2)
    if [ -n "$from_link" ]; then
        printf '%s\n' "$from_link"
        return 0
    fi

    dots_default_root
}
