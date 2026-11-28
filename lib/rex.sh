# Superlogical Rex: the Mac app on macOS, the server package on Linux.
# Sourced by setup.sh, which provides log_*, command_exists, record_failure
# and DRY_RUN.
#
# Docs: https://www.superlogical.com/rex/docs/installation
#
# macOS: Rex for Mac is a closed-beta download with no Homebrew cask and no
# scripted installer, so setup only reports whether Rex.app is present.
#
# Linux: the signed apt repository that the official install.sh sets up,
# written out step by step: keyring, deb822 source, and an apt pin. Debian
# ships an unrelated Perl package also named rex, (R)?ex, at a higher version
# number, so the pin gives Rex's repository priority 1001 and every other rex
# -1. The keyring is checked against REX_KEY_FINGERPRINT before it is saved.
#
# The channel is stable. Until Superlogical publishes a stable release the
# stable suite does not exist, so setup falls back to preview, as install.sh
# does. A machine already on stable never moves back to preview.
#
# The personal server runs as the user: the package's user rex.socket
# socket-activates the user rex.service on a local unix socket, and linger
# keeps it running while logged out. No network listeners are configured.
#
# DOTS_SKIP_REX=1 skips all of this.

REX_REPO="https://pkgs.superlogical.com/rex"
REX_KEY_FINGERPRINT="E28636AC71905C6DDE40C1EDFAA6B80F641307A7"
REX_DOCS="https://www.superlogical.com/rex/docs/installation"
# Overridable so the regression tests can write somewhere other than /etc.
REX_APT_ETC="${REX_APT_ETC:-/etc/apt}"

REX_SUDO=()

install_rex() {
    if [ "${DOTS_SKIP_REX:-0}" = 1 ]; then
        log_info "Rex: skipped because DOTS_SKIP_REX=1."
        return 0
    fi
    case "$(uname)" in
        Darwin) check_rex_mac ;;
        Linux) install_rex_linux ;;
        *) log_info "Rex: no install path for $(uname); skipping." ;;
    esac
}

check_rex_mac() {
    if [ -d /Applications/Rex.app ] || [ -d "$HOME/Applications/Rex.app" ]; then
        log_info "Rex for Mac is installed. It runs its own server."
        return 0
    fi
    log_warning "Rex for Mac is not installed. It has no Homebrew cask or scripted installer."
    log_info "  Download it from $REX_DOCS (closed beta) and move Rex.app to /Applications."
}

# Sets REX_SUDO to what runs a command as root. Returns 1 when that needs a
# password and there is no terminal to type it in.
rex_resolve_sudo() {
    REX_SUDO=()
    [ "$(id -u)" -eq 0 ] && return 0
    if ! command_exists sudo; then
        return 1
    fi
    REX_SUDO=(sudo)
    if [ ! -t 0 ]; then
        sudo -n true >/dev/null 2>&1 || return 1
        REX_SUDO=(sudo -n)
    fi
}

rex_root() {
    ${REX_SUDO[@]+"${REX_SUDO[@]}"} "$@"
}

rex_package_installed() {
    command_exists dpkg-query || return 1
    case "$(dpkg-query -W -f '${Maintainer}' rex 2>/dev/null)" in
        *[Ss]uperlogical*) return 0 ;;
    esac
    return 1
}

# True when $1 is a signed apt Release file for a Rex channel.
rex_suite_exists() {
    local body
    body=$(curl -fsSL "$REX_REPO/apt/dists/$1/InRelease" 2>/dev/null) || return 1
    case "$body" in
        *"BEGIN PGP SIGNED MESSAGE"*) return 0 ;;
    esac
    return 1
}

rex_pick_channel() {
    local current=""
    if [ -f "$REX_APT_ETC/sources.list.d/rex.sources" ]; then
        current=$(sed -n 's/^Suites: *//p' "$REX_APT_ETC/sources.list.d/rex.sources")
    fi
    if [ "$current" = stable ] || rex_suite_exists stable; then
        printf '%s\n' stable
        return 0
    fi
    if rex_suite_exists preview; then
        log_warning "Rex has no stable release yet; using the preview channel. Re-run setup to move to stable once it ships." >&2
        printf '%s\n' preview
        return 0
    fi
    return 1
}

# Install $1 to $2 (mode 0644) as root unless $2 already matches.
# Returns 0 when nothing changed, 10 when the file was written, 1 on failure.
rex_put_file() {
    if [ -f "$2" ] && cmp -s "$1" "$2"; then
        return 0
    fi
    if rex_root install -m 0644 "$1" "$2"; then
        log_success "Wrote $2"
        return 10
    fi
    log_error "Could not write $2"
    return 1
}

# Downloads the keyring and checks its primary key fingerprint into $1.
rex_fetch_keyring() {
    local out="$1" fpr
    if ! curl -fsSLo "$out" "$REX_REPO/keys/rex-archive-keyring.gpg"; then
        log_error "Could not download the Rex signing key."
        return 1
    fi
    fpr=$(gpg --show-keys --with-colons "$out" 2>/dev/null | sed -n 's/^fpr:*\([0-9A-F]*\):*$/\1/p' | head -n1)
    if [ "$fpr" != "$REX_KEY_FINGERPRINT" ]; then
        log_error "Rex signing key fingerprint is '${fpr:-unreadable}', expected $REX_KEY_FINGERPRINT. Not trusting it."
        return 1
    fi
}

# Writes the keyring, source, and pin. Returns 10 when any of them changed.
rex_configure_apt() {
    local channel="$1" arch="$2" tmp status changed=0
    tmp=$(mktemp -d)

    if ! rex_fetch_keyring "$tmp/keyring.gpg"; then
        rm -rf "$tmp"
        return 1
    fi

    cat >"$tmp/rex.sources" <<EOF
Types: deb
URIs: $REX_REPO/apt
Suites: $channel
Components: main
Architectures: $arch
Signed-By: $REX_APT_ETC/keyrings/rex-archive-keyring.gpg
EOF
    cat >"$tmp/rex.pref" <<EOF
Package: rex
Pin: origin pkgs.superlogical.com
Pin-Priority: 1001

Package: rex
Pin: release *
Pin-Priority: -1
EOF

    if ! rex_root install -d -m 0755 "$REX_APT_ETC/keyrings" "$REX_APT_ETC/sources.list.d" "$REX_APT_ETC/preferences.d"; then
        log_error "Could not create apt directories under $REX_APT_ETC"
        rm -rf "$tmp"
        return 1
    fi

    local pair
    for pair in "keyring.gpg:keyrings/rex-archive-keyring.gpg" \
        "rex.sources:sources.list.d/rex.sources" \
        "rex.pref:preferences.d/rex"; do
        status=0
        rex_put_file "$tmp/${pair%%:*}" "$REX_APT_ETC/${pair#*:}" || status=$?
        case "$status" in
            0) ;;
            10) changed=1 ;;
            *) rm -rf "$tmp"; return 1 ;;
        esac
    done
    rm -rf "$tmp"
    [ "$changed" -eq 1 ] && return 10
    return 0
}

# apt must be about to install rex from Rex's repository, never (R)?ex.
rex_candidate_ok() {
    local candidate
    candidate=$(LC_ALL=C apt-cache policy rex 2>/dev/null | sed -n 's/^ *Candidate: *//p')
    [ -n "$candidate" ] && [ "$candidate" != "(none)" ] || return 1
    LC_ALL=C apt-cache madison rex 2>/dev/null | tr -s ' ' \
        | grep -F -- "rex | $candidate | $REX_REPO/apt " >/dev/null
}

install_rex_linux() {
    local arch channel status

    if ! command_exists apt-get || ! command_exists dpkg; then
        log_info "Rex: this Linux system does not use apt; skipping. See $REX_DOCS"
        return 0
    fi
    arch=$(dpkg --print-architecture 2>/dev/null) || arch=""
    case "$arch" in
        amd64|arm64) ;;
        *)
            log_info "Rex: no package for architecture '${arch:-unknown}' (amd64 and arm64 only); skipping."
            return 0
            ;;
    esac

    if [ "${DRY_RUN:-false}" = true ]; then
        log_info "Would set up the Rex apt repository ($REX_REPO/apt, stable, else preview) and install rex"
        log_info "Would enable the user rex.socket and turn on linger for $(id -un)"
        return 0
    fi

    if ! command_exists curl; then
        log_error "Rex: curl is required to set up the Rex apt repository."
        record_failure "Rex install"
        return 0
    fi
    if ! rex_resolve_sudo; then
        log_error "Rex: apt needs root, and sudo needs a password with no terminal attached. Not installing Rex."
        record_failure "Rex install"
        return 0
    fi
    if ! command_exists gpg; then
        log_info "Rex: installing gnupg to check the signing key."
        if ! rex_root env DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg; then
            log_error "Rex: could not install gnupg."
            record_failure "Rex install"
            return 0
        fi
    fi

    if ! channel=$(rex_pick_channel); then
        log_error "Rex: could not reach $REX_REPO/apt (neither stable nor preview)."
        record_failure "Rex install"
        return 0
    fi

    status=0
    rex_configure_apt "$channel" "$arch" || status=$?
    if [ "$status" -ne 0 ] && [ "$status" -ne 10 ]; then
        record_failure "Rex install"
        return 0
    fi

    if [ "$status" -eq 0 ] && rex_package_installed; then
        log_info "Rex is installed from the $channel channel. apt upgrades it."
    else
        log_info "Installing Rex from the $channel channel..."
        if ! rex_root apt-get update; then
            log_warning "apt-get update reported errors. Continuing with the package lists on disk."
        fi
        if ! rex_candidate_ok; then
            log_error "Rex: apt would not install rex from $REX_REPO/apt. Check 'apt-cache policy rex'."
            record_failure "Rex install"
            return 0
        fi
        # --allow-downgrades lets the pin replace (R)?ex, whose version sorts higher.
        if ! rex_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades \
            -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold rex; then
            log_error "Rex: apt-get install rex failed."
            record_failure "Rex install"
            return 0
        fi
        log_success "Installed Rex ($channel channel)."
    fi

    enable_rex_user_server
}

# User rex.socket plus linger, as the login user. Root gets no personal server.
enable_rex_user_server() {
    local user
    user=$(id -un)

    if [ "$(id -u)" -eq 0 ]; then
        log_info "Rex: running as root; not enabling a personal server. Re-run setup as your user."
        return 0
    fi
    if ! command_exists systemctl || ! systemctl --user show-environment >/dev/null 2>&1; then
        log_info "Rex: no systemd user manager; skipping the persistent server. rex starts one on demand."
        return 0
    fi

    if systemctl --user is-enabled rex.socket >/dev/null 2>&1; then
        log_info "Rex: user rex.socket already enabled."
    elif systemctl --user enable --now rex.socket; then
        log_success "Rex: enabled the user rex.socket."
    else
        log_error "Rex: could not enable the user rex.socket."
        record_failure "Rex server"
        return 0
    fi

    if [ "$(loginctl show-user "$user" --property=Linger --value 2>/dev/null)" = yes ]; then
        log_info "Rex: linger already on for $user."
    elif loginctl enable-linger "$user"; then
        log_success "Rex: turned on linger for $user, so the server survives logout."
    else
        log_warning "Rex: could not turn on linger. An admin can run: loginctl enable-linger $user"
        record_failure "Rex linger"
    fi
}
