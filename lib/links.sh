# Managed symlinks shared by setup.sh and update.sh.
# Sourced by bash only. The caller sets DOTS_REPO_DIR to the clone it runs from.

# Deliberately looser than _dots_root_is_clone: checkouts cloned before
# lib/dots-root.sh existed must still be recognised so their links relink.
is_dots_checkout() {
    [ -n "${1:-}" ] || return 1
    [ -f "$1/setup.sh" ] || return 1
    [ -f "$1/zsh/zshrc" ] || return 1
}

# Print the validated checkout root when $1 links to its repo-relative $2.
# A matching suffix is not enough: unrelated and ambiguous dangling links
# must never be treated as dotfiles managed by these scripts.
checkout_root_for_link() {
    local path="$1"
    local rel="$2"
    local target candidate remainder
    if [ ! -L "$path" ]; then
        return 1
    fi
    target=$(readlink "$path") || return 1
    case "$target" in
        /*) ;;
        *) target="$(dirname "$path")/$target" ;;
    esac

    candidate="$target"
    remainder="$rel"
    while [ -n "$remainder" ]; do
        candidate=$(dirname "$candidate")
        case "$remainder" in
            */*) remainder="${remainder#*/}" ;;
            *) remainder="" ;;
        esac
    done

    [ "$target" = "$candidate/$rel" ] || return 1
    if [ "$candidate" = "${DOTS_REPO_DIR:-}" ] || is_dots_checkout "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

# One line per managed link: profile|kind|repo-relative source|destination.
# kind is "optional" when the source may be absent from a checkout
# (gitignored or not yet added); a missing "required" source is a failure.
dots_link_table() {
    printf '%s\n' \
        "minimal|required|zsh/zshrc|$HOME/.zshrc" \
        "minimal|required|zsh/zshenv|$HOME/.zshenv" \
        "minimal|optional|zsh/zprofile|$HOME/.zprofile" \
        "minimal|required|starship/starship.toml|$HOME/.config/starship.toml" \
        "minimal|required|git/gitconfig|$HOME/.gitconfig" \
        "minimal|required|git/gitignore_global|$HOME/.gitignore_global" \
        "minimal|optional|git/delta-catppuccin.gitconfig|$HOME/.config/delta/catppuccin.gitconfig" \
        "minimal|required|lib/dots-root.sh|$HOME/.config/zsh/dots-root.sh" \
        "minimal|optional|zsh/aliases|$HOME/.config/zsh/aliases" \
        "minimal|optional|zsh/hosts|$HOME/.config/zsh/hosts" \
        "minimal|optional|zsh/profile-macos|$HOME/.config/zsh/profile-macos" \
        "minimal|optional|zsh/profile-linux|$HOME/.config/zsh/profile-linux" \
        "minimal|optional|zsh/profile-work|$HOME/.config/zsh/profile-work" \
        "minimal|required|ghostty|$HOME/.config/ghostty" \
        "full|required|vim/vimrc|$HOME/.vimrc" \
        "full|required|tmux/tmux.conf|$HOME/.tmux.conf" \
        "full|required|opencode/opencode.json|$HOME/.config/opencode/opencode.json" \
        "full|required|nvim|$HOME/.config/nvim" \
        "full|required|btop/btop.conf|$HOME/.config/btop/btop.conf" \
        "full|required|btop/themes/catppuccin_mocha.theme|$HOME/.config/btop/themes/catppuccin_mocha.theme" \
        "ai|required|claude/hooks|$HOME/.claude/hooks" \
        "ai|required|claude/scripts|$HOME/.claude/scripts" \
        "ai|required|claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
    # cmd chords and macos-* keys live in a file Ghostty loads only on Darwin.
    if [ "$(uname)" = "Darwin" ]; then
        printf 'minimal|required|ghostty/macos|%s\n' \
            "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    fi
}
