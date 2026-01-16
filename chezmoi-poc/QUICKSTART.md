# Quick Start Guide

## Prerequisites (First-Time Setup)

If this is your first time using the Chezmoi POC (e.g., in a fresh VM):

```bash
cd ~/dots/chezmoi-poc
./bootstrap.sh
```

**What it installs:**
- **Homebrew** (macOS only, if missing)
- **chezmoi** (the dotfile manager)
- **1Password desktop app** (macOS only, for signing in)
- **1Password CLI** (macOS only, for secrets integration)

**Takes:** ~2-5 minutes depending on your connection

After bootstrap completes, continue with the instructions below.

---

## 🚀 Test the POC in 5 Minutes

### 1. Install Chezmoi (if not installed)

**macOS:**
```bash
brew install chezmoi
```

**Linux:**
```bash
curl -sfL https://git.io/chezmoi | sh
```

### 2. Run the Test Script

```bash
cd ~/dots/chezmoi-poc
./TEST.sh
```

Choose option 1 to preview what would happen (dry run).

### 3. See Template Output

```bash
# See what your zshrc would look like
chezmoi init --source ~/dots/chezmoi-poc
chezmoi cat ~/.zshrc

# See what your gitconfig would look like
chezmoi cat ~/.gitconfig

# See all available variables
chezmoi data
```

### 4. Preview Changes (Safe)

```bash
# Show what files would be created/modified
chezmoi init --source ~/dots/chezmoi-poc
chezmoi diff
```

### 5. Actually Apply (When Ready)

```bash
# Apply the POC to your home directory
chezmoi apply -v

# This will:
# - Create templated dotfiles
# - Run installation scripts
# - Install packages (if on macOS)
# - Set up plugins
```

---

## 🎯 What Each File Does

### Core Configuration
- **`.chezmoi.toml.tmpl`** - Prompts for your name/email on first run, stores machine-specific config
- **`.chezmoiignore`** - Skip platform-specific files (e.g., don't install macOS configs on Linux)

### Your Dotfiles (Templates)
- **`dot_zshrc.tmpl`** → `~/.zshrc` - Platform-aware shell config
- **`dot_gitconfig.tmpl`** → `~/.gitconfig` - Git config with your name/email auto-filled
- **`dot_tmux.conf`** → `~/.tmux.conf` - Static file (no templating needed)
- **`dot_config/starship/`** → `~/.config/starship/` - Starship prompt

### Package Management
- **`Brewfile.tmpl`** → `~/.Brewfile` - All your Homebrew packages
- **`run_once_before_install-packages.sh.tmpl`** - Installs Homebrew + packages
- **`run_onchange_after_brewfile-update.sh.tmpl`** - Auto-updates when Brewfile changes

### Plugin Setup
- **`run_once_after_install-plugins.sh.tmpl`** - Installs Zinit, TPM, sets zsh as default

### macOS Settings
- **`run_once_after_configure-macos.sh.tmpl`** - Configures Finder, Dock, keyboard, etc.

---

## 🧪 Safe Testing Methods

### Method 1: Docker (Safest)
```bash
# Test on Ubuntu
docker run -it --rm ubuntu:latest bash -c '
  apt update && apt install -y git curl sudo
  sh -c "$(curl -fsLS get.chezmoi.io)"
  # Then manually test
'
```

### Method 2: VM (Safe)
- Create fresh macOS/Linux VM
- Clone your dotfiles
- Run chezmoi init/apply
- Snapshot VM before testing

### Method 3: Dry Run (Safe on Current Machine)
```bash
# Only preview, don't apply
cd ~/dots/chezmoi-poc
chezmoi init --source .
chezmoi diff                    # See what would change
chezmoi cat ~/.zshrc            # See templated output
chezmoi managed                 # List files that would be managed
```

---

## 📋 Decision Checklist

Should you migrate to Chezmoi?

**✅ Migrate if you want:**
- [ ] Single-command machine setup
- [ ] Secrets from 1Password in configs
- [ ] Platform-specific configs (Mac vs Linux)
- [ ] Automatic package installation
- [ ] macOS system settings as code
- [ ] Industry-standard IaC approach
- [ ] Better portability across machines

**❌ Stay with current setup if:**
- [ ] Current setup already works perfectly
- [ ] Don't want to learn new tool
- [ ] Rarely set up new machines
- [ ] Don't need templates/secrets
- [ ] Prefer simplicity over features

**🤔 Consider Ansible instead if:**
- [ ] Want to learn Ansible for career
- [ ] Manage multiple machines/servers
- [ ] Need advanced system configuration
- [ ] Work in DevOps/SRE role

---

## 🎓 Learning Path

### Week 1: Understand Chezmoi
```bash
# Read docs
open https://www.chezmoi.io/quick-start/

# Test POC
cd ~/dots/chezmoi-poc
./TEST.sh

# Experiment with templates
chezmoi init --source ~/dots/chezmoi-poc
chezmoi cat ~/.zshrc    # See output
chezmoi data            # See variables
```

### Week 2: Gradual Migration
```bash
# Create migration branch
cd ~/dots
git checkout -b chezmoi-migration

# Start converting files
chezmoi init
chezmoi add ~/.gitconfig          # Add as static
chezmoi chattr template ~/.gitconfig  # Convert to template
chezmoi edit ~/.gitconfig         # Customize template

# Test each file
chezmoi diff
chezmoi apply -v
```

### Week 3: Add Features
```bash
# Add Brewfile
chezmoi cd
# Create Brewfile.tmpl with your packages

# Add run scripts
# Create run_once_before_install-packages.sh.tmpl

# Test on VM or new machine
```

### Week 4: Full Migration
```bash
# Commit everything
git add .
git commit -m "Migrate to Chezmoi"
git push

# Test from GitHub
chezmoi init --apply https://github.com/just1jray/dots.git
```

---

## 🔐 1Password Integration (Advanced)

### Enable Integration

When you run `chezmoi init --source .`, you'll be prompted:

```
name [Your Name]: Jesse Ray
email [your.email@example.com]: jesse@example.com
work (bool) [false]: f
use_1password (bool) [false]: t    ← Single char works! t=true, f=false
1password_github_ref [op://Private/GitHub/credential]: op://Private/GitHub Token/credential
```

**Note:** The last prompt only appears if you answer "t" (true) to `use_1password`.

**Boolean shortcuts:**
- **t**, y, true, yes, 1 = enable
- **f**, n, false, no, 0 = disable

**If you enable it (`true`):**
- Chezmoi will automatically fetch secrets from 1Password
- You MUST run `op signin` before `chezmoi apply`
- You'll specify the exact 1Password item reference
- Templates will use real secrets from your vault

**If you disable it (`false`, default):**
- No 1Password integration
- Standard credential helpers used
- No `op signin` required

### Prerequisites
1. Run `./bootstrap.sh` (installs 1Password desktop app and CLI automatically on macOS)
2. Open 1Password app and sign in to your account
3. Enable CLI in 1Password settings: Settings → Developer → Command-Line Interface
4. Sign in to CLI: `op signin`

### Store Secrets in 1Password

**Create a unique item:**
1. Open 1Password desktop app
2. Create a new item in "Private" vault
3. **Use a unique name** like "GitHub Token" (not just "GitHub")
4. Add a field called "credential" with your GitHub personal access token

**Item reference format:**
```
op://VAULT/ITEM_NAME/FIELD_NAME
```

**Examples to enter at the prompt:**
```bash
# ✅ Good - unique item names
op://Private/GitHub Token/credential
op://Private/GitHub Personal Access Token/token
op://Private/My GitHub PAT/password

# ❌ Bad - will fail if multiple "GitHub" items exist
op://Private/GitHub/credential
```

**Troubleshooting:** If you see "More than one item matches":
- Rename your items in 1Password to be unique, OR
- Use the item ID: `op://Private/63ztuiynkmjtdjajw37u4iux2m/credential`
  - Find ID with: `op item list --vault Private | grep "GitHub"`

### How It Works
The templates automatically check the `use_1password` flag:

```toml
# .chezmoi.toml.tmpl
{{- if $use_1password }}
    github_token = {{ onepasswordRead "op://Private/GitHub/credential" | quote }}
{{- end }}
```

No need to uncomment anything - just answer the prompt!

### Security Notes
- Secrets never stored in Git
- Retrieved at apply time only
- Requires 1Password unlocked
- Can use Touch ID/biometrics

---

## 🆘 Troubleshooting

### "Template execution failed"
```bash
# Check syntax
chezmoi execute-template < dot_zshrc.tmpl

# Check variables
chezmoi data
```

### "File already exists"
```bash
# Chezmoi won't overwrite non-symlinks
# Back up first:
mv ~/.zshrc ~/.zshrc.backup

# Or force:
chezmoi apply --force
```

### "Script didn't run"
```bash
# Check script permissions
chezmoi cd
ls -la run_*.sh*

# Make executable if needed
chmod +x run_once_before_install-packages.sh.tmpl

# Force re-run
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply -v
```

### "Wrong template output"
```bash
# Check variables
chezmoi data

# Check template manually
chezmoi cat ~/.zshrc

# Edit template
chezmoi edit ~/.zshrc
```

---

## 📚 Resources

### Documentation
- [Chezmoi Quick Start](https://www.chezmoi.io/quick-start/)
- [Chezmoi User Guide](https://www.chezmoi.io/user-guide/command-overview/)
- [Template Reference](https://www.chezmoi.io/user-guide/templating/)
- [1Password Integration](https://www.chezmoi.io/user-guide/password-managers/1password/)

### Examples
- [Tom Payne's dotfiles](https://github.com/twpayne/dotfiles) - Chezmoi author
- [Chezmoi GitHub Topic](https://github.com/topics/chezmoi)

### Comparison Docs
- See `ANSIBLE_COMPARISON.md` in this directory
- See `README.md` for full migration guide

---

## ⏭️ Next Steps

1. **Test the POC**
   ```bash
   cd ~/dots/chezmoi-poc
   ./TEST.sh
   ```

2. **Decide**: Chezmoi, Ansible, or keep current setup?

3. **If Chezmoi**: Follow migration guide in `README.md`

4. **If Ansible**: See `ANSIBLE_COMPARISON.md` for learning path

5. **Questions?** Open issue or ask!
