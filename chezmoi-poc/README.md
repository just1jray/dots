# Chezmoi Proof of Concept for Dotfiles

This is a proof-of-concept conversion of your dotfiles to use Chezmoi for IaC-style management.

## What's in this POC?

### Configuration Files
- **`.chezmoi.toml.tmpl`** - Chezmoi configuration with machine-specific variables
  - Prompts for name, email, and work/personal on first run
  - Shows 1Password integration examples (commented out)
  - Platform detection for macOS vs Linux

### Templated Files (`.tmpl`)
- **`dot_zshrc.tmpl`** - Templated zshrc with platform-specific logic
  - Uses Go templates to generate platform-specific config at install time
  - Work profile only loads on work machines
  - Auto-tmux only on macOS

- **`dot_gitconfig.tmpl`** - Git config with user info from Chezmoi vars
  - User name/email auto-filled from `.chezmoi.toml.tmpl`
  - Platform-specific credential helpers (osxkeychain on Mac)
  - SSH signing example for specific hostnames
  - 1Password integration examples (commented)

- **`Brewfile.tmpl`** - Platform-aware Homebrew package list
  - Only applies on macOS
  - Different packages for work vs personal machines
  - Includes 1password-cli for secrets integration

### Static Files (no templating)
- **`dot_tmux.conf`** - Tmux configuration (no platform differences needed)
- **`dot_config/starship/starship.toml`** - Starship prompt config

### Run Scripts
Scripts execute automatically at the right time in the Chezmoi lifecycle:

1. **`run_once_before_install-packages.sh.tmpl`** - Runs BEFORE dotfiles are linked
   - Installs Homebrew (macOS) or apt packages (Linux)
   - Runs `brew bundle` to install from Brewfile
   - Installs essential tools (starship, fzf, zoxide, etc.)

2. **`run_once_after_install-plugins.sh.tmpl`** - Runs AFTER dotfiles are linked
   - Installs Zinit (zsh plugin manager)
   - Installs TPM (tmux plugin manager)
   - Sets zsh as default shell
   - Creates necessary directories

3. **`run_onchange_after_brewfile-update.sh.tmpl`** - Runs when Brewfile changes
   - Auto-runs `brew bundle` when you modify Brewfile
   - Uses hash to detect changes

4. **`run_once_after_configure-macos.sh.tmpl`** - macOS system settings (macOS only)
   - Configures Finder settings (show hidden files, extensions, path bar)
   - Dock settings (size, auto-hide, no recents)
   - Keyboard settings (fast repeat, disable auto-correct)
   - Screenshot settings (PNG, no shadow, custom location)
   - Activity Monitor, Terminal, and developer settings

### Other Files
- **`.chezmoiignore`** - Files/patterns to skip during installation
  - Platform-specific ignoring (don't install macOS configs on Linux)
  - Work-specific file filtering

- **`symlink_dot_Brewfile.tmpl`** - Creates symlink: `~/.Brewfile` → source

## How It Works

### File Naming Convention
Chezmoi uses special prefixes in filenames:

- `dot_` → `.` (hidden file)
  - `dot_zshrc` → `~/.zshrc`
  - `dot_config/nvim/` → `~/.config/nvim/`

- `.tmpl` → Template (processed with Go templates)
  - `dot_zshrc.tmpl` → `~/.zshrc` (after template rendering)

- `run_once_` → Run script once per machine
- `run_onchange_` → Run when file content changes
- `run_before_` → Run before applying dotfiles
- `run_after_` → Run after applying dotfiles

- `symlink_` → Create symlink instead of copying

### Template Variables
In `.tmpl` files, you can use:

```go
{{ .chezmoi.os }}           // "darwin" or "linux"
{{ .chezmoi.arch }}         // "amd64" or "arm64"
{{ .chezmoi.hostname }}     // Machine hostname
{{ .chezmoi.username }}     // Current user
{{ .chezmoi.sourceDir }}    // Chezmoi source directory
{{ .name }}                 // Custom var from .chezmoi.toml.tmpl
{{ .email }}                // Custom var from .chezmoi.toml.tmpl
{{ .work }}                 // Custom boolean from .chezmoi.toml.tmpl

// Conditionals
{{- if eq .chezmoi.os "darwin" }}
macOS-specific content
{{- else if eq .chezmoi.os "linux" }}
Linux-specific content
{{- end }}

// 1Password integration (requires 1password-cli)
{{ onepasswordRead "op://Private/GitHub/token" }}
```

## Testing the POC

### Option 1: Test in Docker (Safe)
```bash
# Test on Ubuntu
docker run -it ubuntu:latest bash
# Inside container:
apt update && apt install -y git curl sudo
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $YOUR_GITHUB_USER/dots

# Test on macOS (requires Docker Desktop)
# Note: Limited testing, can't test full macOS features
```

### Option 2: Test in VM
Use UTM, Parallels, or VirtualBox with a fresh macOS/Linux VM

### Option 3: Test on Current Machine (with dry-run)
```bash
# Install Chezmoi
brew install chezmoi  # macOS
# or
curl -sfL https://git.io/chezmoi | sh  # Linux

# Initialize with this POC directory
cd ~/dots/chezmoi-poc
chezmoi init --source .

# Preview what would happen (DRY RUN)
chezmoi diff

# See what files would be created
chezmoi managed

# Apply to home directory (creates actual files)
# chezmoi apply -v
```

## Migration Path

### Phase 1: Initial Setup (Do this first)
1. Install Chezmoi: `brew install chezmoi`
2. Install 1Password CLI: `brew install --cask 1password-cli` (optional)
3. Create a test branch: `git checkout -b chezmoi-migration`

### Phase 2: Convert Files Gradually
```bash
# Initialize Chezmoi with existing dotfiles
cd ~/Developer/src/dots
chezmoi init

# Add files one by one
chezmoi add ~/.zshrc           # Adds as static file
chezmoi add ~/.gitconfig       # Adds as static file

# Convert to templates when needed
chezmoi chattr template ~/.zshrc
chezmoi edit ~/.zshrc          # Opens in editor, add template logic

# Preview changes
chezmoi diff

# Apply when ready
chezmoi apply
```

### Phase 3: Add Features
1. **Add platform detection** - Convert configs to templates with `{{ .chezmoi.os }}`
2. **Add package management** - Create `run_once_before_install-packages.sh.tmpl`
3. **Add Brewfile** - Create `Brewfile.tmpl` and symlink
4. **Add 1Password** - Set up secrets in `.chezmoi.toml.tmpl`
5. **Add macOS settings** - Create `run_once_after_configure-macos.sh.tmpl`

### Phase 4: Full Migration
```bash
# Move Chezmoi files to main repo
cd ~/dots
cp -r chezmoi-poc/* .
rm -rf chezmoi-poc/

# Update README
# Commit changes
git add .
git commit -m "Migrate to Chezmoi for IaC-style dotfile management"

# Test on a fresh machine or VM
chezmoi init --apply https://github.com/just1jray/dots.git
```

## Comparison: Before vs After

### Before (Current Setup)
```bash
# Clone repo
git clone https://github.com/just1jray/dots.git ~/Developer/src/dots
cd ~/Developer/src/dots

# Run setup script
./setup.sh

# Manual: Install packages
brew install starship fzf zoxide neovim tmux

# Manual: Configure macOS settings
# (not automated)
```

### After (Chezmoi)
```bash
# One command setup
chezmoi init --apply https://github.com/just1jray/dots.git

# Everything happens automatically:
# ✅ Packages installed via Brewfile
# ✅ Dotfiles linked
# ✅ Plugins installed
# ✅ macOS settings configured
# ✅ Platform-specific configs applied
```

## Using 1Password Integration

### Setup
1. Install 1Password desktop app and CLI
2. Sign in: `op signin`
3. Enable CLI integration in 1Password settings

### Store Secrets
```bash
# Store GitHub token in 1Password
# Item: "GitHub" in "Private" vault
# Field: "credential" or "token"

# Store SSH key
# Item: "SSH" in "Private" vault
# Field: "signing_key"
```

### Use in Templates
Uncomment the 1Password lines in `.chezmoi.toml.tmpl` and templates:

```toml
# .chezmoi.toml.tmpl
[data]
    github_token = {{ onepasswordRead "op://Private/GitHub/credential" | quote }}
```

```gitconfig
# dot_gitconfig.tmpl
[credential "https://github.com"]
    helper = !echo "username=just1jray\npassword={{ .github_token }}"
```

## Next Steps

1. **Test this POC** - Try `chezmoi init --source ~/dots/chezmoi-poc`
2. **Decide on migration** - Is this worth switching?
3. **Gradual adoption** - Can migrate file-by-file
4. **Add features** - Start with Brewfile, then templates, then 1Password

## Resources

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Chezmoi How-To Guide](https://www.chezmoi.io/user-guide/command-overview/)
- [Template Reference](https://www.chezmoi.io/user-guide/templating/)
- [1Password Integration](https://www.chezmoi.io/user-guide/password-managers/1password/)

## Learning Ansible (for Professional Development)

While this POC focuses on Chezmoi, here's how to learn Ansible:

### Ansible for Dotfiles - Quick Start
```bash
# Install Ansible
brew install ansible  # macOS
# or
pip install ansible   # Cross-platform

# Create basic playbook
mkdir -p ansible-dotfiles/{roles,inventory}
cd ansible-dotfiles
```

Create `playbook.yml`:
```yaml
---
- hosts: localhost
  roles:
    - homebrew
    - dotfiles
```

See comparison in next section for full Ansible example.

### Learning Resources
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible for DevOps Book](https://www.ansiblefordevops.com/) (free)
- [Learn Ansible in Y Minutes](https://learnxinyminutes.com/docs/ansible/)
- Practice: Set up lab VMs and use Ansible to configure them
