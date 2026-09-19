# Resolve the dotfiles clone for the `dots` shortcut.
# Shared by bash (update.sh) and zsh (zsh/aliases).
# Do not enable set -e here: interactive zsh sources this file.
#
# Precedence:
#   1. $DOTS_DIR
#   2. symlink target of ~/.zshrc (<clone>/zsh/zshrc)
#   3. symlink target of ~/.config/zsh/aliases (<clone>/zsh/aliases)
#   4. $HOME/Developer/src/dots
#
# Rules 2 and 3 only apply when the derived directory actually looks like this
# clone (see _dots_root_is_clone). A ~/.zshrc pointing somewhere unrelated,
# such as ~/.oh-my-zsh/templates/zshrc, falls through to the next rule instead
# of returning a wrong path.

dots_default_root() {
    printf '%s\n' "${HOME}/Developer/src/dots"
}

# True when $1 looks like a checkout of this dotfiles repo.
_dots_root_is_clone() {
    [ -n "${1:-}" ] || return 1
    [ -d "$1" ] || return 1
    [ -f "$1/setup.sh" ] || return 1
    [ -f "$1/lib/dots-root.sh" ] || return 1
    return 0
}

# Print the clone root implied by a symlink, or nothing.
# $1 = symlink path, $2 = directory levels from the target up to the clone.
# Note: never name a local `path` here. In zsh `path` is tied to `PATH`,
# so a local by that name blanks the command search path inside the function.
_dots_root_from_link() {
    local link_path="$1"
    local depth="$2"
    local target
    local i

    if [ ! -L "$link_path" ]; then
        return 0
    fi

    target=$(readlink "$link_path") || return 0
    case "$target" in
        /*) ;;
        *) target="$(dirname "$link_path")/$target" ;;
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
    if _dots_root_is_clone "$from_link"; then
        printf '%s\n' "$from_link"
        return 0
    fi

    # ~/.config/zsh/aliases -> <clone>/zsh/aliases
    from_link=$(_dots_root_from_link "$HOME/.config/zsh/aliases" 2)
    if _dots_root_is_clone "$from_link"; then
        printf '%s\n' "$from_link"
        return 0
    fi

    dots_default_root
}
