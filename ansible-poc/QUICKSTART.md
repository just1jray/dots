# Ansible Dotfiles - Quick Start Guide

Get started with Ansible dotfile management in 10 minutes.

## ⚡ TL;DR

```bash
# Install Ansible
brew install ansible  # macOS
# or
sudo apt install ansible  # Linux

# Install required collection
ansible-galaxy collection install community.general

# Go to POC directory
cd ~/dots/ansible-poc

# Edit your info (optional)
nano group_vars/all.yml
# Change git_user_name and git_user_email

# Preview changes (dry run)
ansible-playbook playbook.yml --check --diff

# Apply for real
ansible-playbook playbook.yml
```

---

## 📋 Step-by-Step

### 1. Install Prerequisites

**macOS:**
```bash
# Install Ansible via Homebrew
brew install ansible

# Verify installation
ansible --version
# Should be 2.10 or higher
```

**Linux (Debian/Ubuntu):**
```bash
# Update and install
sudo apt update
sudo apt install -y ansible python3-pip

# Verify
ansible --version
```

### 2. Install Ansible Collections

```bash
# Required for homebrew and osx_defaults modules
ansible-galaxy collection install community.general

# Verify installation
ansible-galaxy collection list | grep community.general
```

### 3. Customize Variables

```bash
cd ~/dots/ansible-poc

# Edit global variables
nano group_vars/all.yml
```

**Minimal required changes:**
```yaml
git_user_name: "Your Name"        # Change this
git_user_email: "your@email.com"  # Change this
```

**Optional changes:**
- Add/remove packages from `homebrew_packages`
- Customize `macos_settings` for different preferences
- Modify `is_work_machine` logic

### 4. Test Configuration (Dry Run)

```bash
# See what would happen WITHOUT making changes
ansible-playbook playbook.yml --check --diff

# This shows:
# - Which files would be created/modified
# - Which packages would be installed
# - Which settings would change
```

**Example output:**
```
TASK [zsh : Deploy zshrc from template]
changed: [localhost]
--- before: /Users/you/.zshrc
+++ after: /Users/you/.zshrc
@@ ... (shows differences)

TASK [homebrew : Install Homebrew packages]
changed: [localhost] => (item=starship)
changed: [localhost] => (item=fzf)
```

### 5. Apply Configuration

```bash
# Run for real (makes actual changes)
ansible-playbook playbook.yml

# With verbose output to see what's happening
ansible-playbook playbook.yml -v
```

### 6. Verify Results

```bash
# Check if packages installed
which starship fzf zoxide

# Check if configs deployed
ls -la ~/.zshrc ~/.gitconfig ~/.tmux.conf

# Check if zsh is default
echo $SHELL
```

---

## 🎯 Common Tasks

### Update Just One Config

```bash
# Only update zsh
ansible-playbook playbook.yml --tags zsh

# Only update git
ansible-playbook playbook.yml --tags git

# Only update macOS settings
ansible-playbook playbook.yml --tags macos
```

### Install Additional Package

```bash
# 1. Edit variables
nano group_vars/all.yml

# 2. Add package to list
homebrew_packages:
  - git
  - starship
  - your-new-package  # Add this

# 3. Run homebrew role only
ansible-playbook playbook.yml --tags homebrew
```

### Preview Changes Before Applying

```bash
# Always run with --check first
ansible-playbook playbook.yml --check --diff

# Review output, then apply if looks good
ansible-playbook playbook.yml
```

---

## 🐛 Troubleshooting

### "Module not found: community.general"

```bash
# Install the collection
ansible-galaxy collection install community.general

# If still fails, specify Python path
ansible-playbook playbook.yml -e ansible_python_interpreter=/usr/bin/python3
```

### "Permission denied" on macOS settings

```bash
# Some settings require Full Disk Access
# System Preferences → Security & Privacy → Privacy → Full Disk Access
# Add Terminal or iTerm2
```

### Homebrew not in PATH during Ansible run

```bash
# The playbook handles this, but if issues persist:
# macOS Apple Silicon:
eval "$(/opt/homebrew/bin/brew shellenv)"

# macOS Intel:
eval "$(/usr/local/bin/brew shellenv)"
```

### Task shows "changed" every time

This might mean the task isn't idempotent. Check if:
- Using `command` instead of a module
- Missing `changed_when: false` on info-gathering tasks
- File permissions changing each run

---

## 📚 What Each File Does

### ansible.cfg
- Ansible configuration
- Sets defaults (colors, timing, etc.)
- Usually don't need to modify

### inventory.yml
- Defines hosts (just localhost for dotfiles)
- Can add host-specific variables here

### playbook.yml
- Main entry point
- Defines which roles run in which order
- High-level orchestration

### group_vars/all.yml
- **MOST IMPORTANT FILE TO EDIT**
- All variables defined here
- Packages, settings, user info, etc.

### roles/*/tasks/main.yml
- What each role does
- Actual Ansible tasks
- Usually don't need to edit

### roles/*/templates/*.j2
- Jinja2 templates
- Generated configs using variables
- Can edit for custom configs

### roles/*/files/*
- Static files copied as-is
- No templating
- Can edit for custom configs

---

## 🎓 Learning Path

### Week 1: Understand
```bash
# Read the files
cat group_vars/all.yml          # Variables
cat playbook.yml                # Orchestration
cat roles/zsh/tasks/main.yml    # Tasks

# Run with --check to see what would happen
ansible-playbook playbook.yml --check --diff
```

### Week 2: Customize
```bash
# Modify variables
nano group_vars/all.yml

# Test changes
ansible-playbook playbook.yml --check --diff

# Apply
ansible-playbook playbook.yml
```

### Week 3: Extend
```bash
# Add new package
# Edit group_vars/all.yml, add to homebrew_packages
ansible-playbook playbook.yml --tags homebrew

# Add new setting
# Edit group_vars/all.yml, add to macos_settings
ansible-playbook playbook.yml --tags macos
```

### Week 4: Create
```bash
# Create new role
mkdir -p roles/mynewrole/tasks
# Add tasks
# Include in playbook.yml
```

---

## 💡 Pro Tips

### 1. Always Check First
```bash
ansible-playbook playbook.yml --check --diff
```
Never run without `--check` first on a new machine!

### 2. Use Tags for Speed
```bash
# Much faster than full run
ansible-playbook playbook.yml --tags zsh
```

### 3. Override Variables at Runtime
```bash
ansible-playbook playbook.yml \
  -e "git_user_name='Different Name'" \
  -e "is_work_machine=true"
```

### 4. Verbose Output for Debugging
```bash
# -v = verbose
# -vv = more verbose
# -vvv = debug level
ansible-playbook playbook.yml -vv
```

### 5. List Everything
```bash
# List all tasks
ansible-playbook playbook.yml --list-tasks

# List all tags
ansible-playbook playbook.yml --list-tags

# List all hosts
ansible-playbook playbook.yml --list-hosts
```

---

## 🔄 Comparison with Current Setup

### Current (setup.sh)
```bash
cd ~/dots
./setup.sh
# Manual package installation
brew install starship fzf zoxide neovim tmux
```

### With Ansible
```bash
cd ~/dots/ansible-poc
ansible-playbook playbook.yml
# Everything automated:
# ✅ Packages installed
# ✅ Configs deployed
# ✅ Plugins installed
# ✅ macOS settings configured
```

---

## 🚀 Next Steps

1. **Read the main README.md** for detailed information
2. **Experiment in VM** if you want to test safely
3. **Customize variables** to match your preferences
4. **Run on real machine** when comfortable
5. **Learn more Ansible** using resources in README.md

---

## 📖 Quick Reference

```bash
# Main commands
ansible-playbook playbook.yml                    # Run everything
ansible-playbook playbook.yml --check --diff     # Dry run
ansible-playbook playbook.yml --tags TAG         # Run specific role
ansible-playbook playbook.yml -e "VAR=value"     # Override variable
ansible-playbook playbook.yml -v                 # Verbose output

# Useful tags
--tags homebrew    # Packages only
--tags zsh         # Zsh only
--tags git         # Git only
--tags tmux        # Tmux only
--tags macos       # macOS settings only

# Information
ansible-playbook playbook.yml --list-tasks       # Show all tasks
ansible-playbook playbook.yml --list-tags        # Show all tags
ansible --version                                # Check Ansible version
ansible-galaxy collection list                   # List installed collections
```

---

**Ready to try it?** Start with:
```bash
cd ~/dots/ansible-poc
ansible-playbook playbook.yml --check --diff
```

This will show you what would happen without making any changes!
