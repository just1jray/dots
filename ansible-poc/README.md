# Ansible Dotfiles Management - Proof of Concept

This is a comprehensive Ansible-based dotfiles management system that demonstrates Infrastructure as Code (IaC) principles for personal development environment configuration.

## 📁 Directory Structure

```
ansible-poc/
├── ansible.cfg                  # Ansible configuration
├── inventory.yml                # Host definitions (localhost)
├── playbook.yml                 # Main playbook - orchestrates all roles
├── group_vars/
│   └── all.yml                  # Global variables (packages, settings, etc.)
└── roles/
    ├── homebrew/               # Package management (macOS)
    │   └── tasks/main.yml
    ├── zsh/                    # Shell configuration
    │   ├── tasks/main.yml
    │   ├── templates/          # Jinja2 templates
    │   │   ├── zshrc.j2
    │   │   └── zshenv.j2
    │   └── files/              # Static files
    │       ├── aliases
    │       ├── profile-macos
    │       └── profile-linux
    ├── git/                    # Version control config
    │   ├── tasks/main.yml
    │   └── templates/
    │       ├── gitconfig.j2
    │       └── gitignore_global.j2
    ├── tmux/                   # Terminal multiplexer
    │   ├── tasks/main.yml
    │   └── files/
    │       └── tmux.conf
    ├── neovim/                 # Editor configuration
    │   └── tasks/main.yml
    └── macos/                  # macOS system settings
        └── tasks/main.yml
```

## ✨ Features

### Infrastructure as Code
- **Declarative Configuration**: Define desired state, Ansible ensures it
- **Idempotent**: Run multiple times safely - only changes what's needed
- **Version Controlled**: All configs in Git with full history
- **Reproducible**: Identical environment on any machine
- **Testable**: Dry-run mode (`--check`) to preview changes

### Package Management
- **Homebrew Integration**: Native `homebrew` and `homebrew_cask` modules
- **Automatic Installation**: Installs Homebrew if not present
- **Work/Personal Profiles**: Different packages based on machine type
- **Common Packages**: starship, fzf, zoxide, neovim, tmux, gh, etc.
- **Work Packages**: kubectl, terraform, ansible, docker (work machines only)

### Platform Intelligence
- **Cross-Platform**: macOS (Intel & Apple Silicon) and Linux (Debian/Ubuntu)
- **Platform Detection**: Automatic OS/architecture detection
- **Conditional Logic**: Different configs per platform using Jinja2
- **Work Machine Detection**: Hostname-based work vs personal

### Configuration Templates
- **Jinja2 Templating**: Dynamic config generation
- **Variables**: User name, email, hostname, OS, architecture
- **Conditionals**: `{% if %}` for platform-specific sections
- **Loops**: Iterate over lists of packages, settings, etc.

### macOS System Settings
- **Native Module**: Uses `osx_defaults` for `defaults write`
- **Comprehensive**: Finder, Dock, keyboard, screenshots
- **Organized**: Settings grouped by category in variables
- **Safe**: Handlers restart only affected apps

## 🚀 Quick Start

### Prerequisites

**macOS:**
```bash
# Install Ansible
brew install ansible

# Install community.general collection (for osx_defaults, homebrew modules)
ansible-galaxy collection install community.general
```

**Linux:**
```bash
# Install Ansible
sudo apt update
sudo apt install -y ansible

# Install collection
ansible-galaxy collection install community.general
```

### Installation

**Option 1: Test Locally** (safest)
```bash
cd ~/dots/ansible-poc

# Customize variables (optional)
nano group_vars/all.yml
# Edit git_user_name and git_user_email

# Dry run (preview changes)
ansible-playbook playbook.yml --check --diff

# Apply configuration
ansible-playbook playbook.yml
```

**Option 2: Install with Custom Variables**
```bash
ansible-playbook playbook.yml \
  -e "git_user_name='Your Name'" \
  -e "git_user_email='your@email.com'"
```

**Option 3: Run Specific Roles**
```bash
# Only configure zsh
ansible-playbook playbook.yml --tags zsh

# Only install packages
ansible-playbook playbook.yml --tags homebrew

# Only configure macOS settings
ansible-playbook playbook.yml --tags macos
```

## 📖 How It Works

### Variables (group_vars/all.yml)

Define everything in one place:
```yaml
git_user_name: "Your Name"
git_user_email: "your@email.com"
is_work_machine: "{{ ansible_hostname is search('work') }}"

homebrew_packages:
  - git
  - starship
  - fzf
  # ...

macos_settings:
  finder:
    - { domain: "com.apple.finder", key: "ShowPathbar", type: "bool", value: "true" }
    # ...
```

### Templates (Jinja2)

Generate platform-specific configs:
```jinja2
# In zshrc.j2
{% if ansible_os_family == "Darwin" %}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{% else %}
# Linux-specific
export PATH="/usr/local/bin:$PATH"
{% endif %}

{% if is_work_machine %}
# Work-specific
source ~/.config/zsh/profile-work
{% endif %}
```

### Tasks (roles/*/tasks/main.yml)

Define what should happen:
```yaml
- name: Install Homebrew packages
  community.general.homebrew:
    name: "{{ homebrew_packages }}"
    state: present
  when: ansible_os_family == "Darwin"
```

### Playbook (playbook.yml)

Orchestrate roles in order:
```yaml
- name: Configure dotfiles
  hosts: localhost
  roles:
    - homebrew    # Install packages first
    - zsh         # Then configure shell
    - git         # Configure git
    - tmux        # Configure tmux
    - neovim      # Configure editor
    - macos       # Finally, OS settings
```

## 🎯 Common Use Cases

### Run Full Setup on New Machine
```bash
cd ~/dots/ansible-poc
ansible-playbook playbook.yml
```

### Preview Changes Before Applying
```bash
ansible-playbook playbook.yml --check --diff
```

### Update Just One Tool
```bash
# Update zsh config only
ansible-playbook playbook.yml --tags zsh

# Update git config only
ansible-playbook playbook.yml --tags git

# Update packages only
ansible-playbook playbook.yml --tags homebrew
```

### Install Additional Packages
```bash
# Edit group_vars/all.yml, add to homebrew_packages
nano group_vars/all.yml

# Run homebrew role
ansible-playbook playbook.yml --tags homebrew
```

### Test on Different Machine Type
```bash
# Override work machine detection
ansible-playbook playbook.yml -e "is_work_machine=true"
```

## 📝 Customization

### Add Your Information

Edit `group_vars/all.yml`:
```yaml
git_user_name: "John Doe"
git_user_email: "john@example.com"
```

### Add More Packages

Edit `group_vars/all.yml`:
```yaml
homebrew_packages:
  - git
  - starship
  - your-new-package  # Add here
```

Then run:
```bash
ansible-playbook playbook.yml --tags homebrew
```

### Add Custom macOS Settings

Edit `group_vars/all.yml`:
```yaml
macos_settings:
  custom:
    - { domain: "com.apple.someapp", key: "SomeSetting", type: "bool", value: "true" }
```

Update `roles/macos/tasks/main.yml`:
```yaml
- name: Configure custom settings
  community.general.osx_defaults:
    domain: "{{ item.domain }}"
    key: "{{ item.key }}"
    type: "{{ item.type }}"
    value: "{{ item.value }}"
  loop: "{{ macos_settings.custom }}"
```

### Create New Role

```bash
# Create role structure
mkdir -p roles/mynewrole/{tasks,templates,files}

# Create tasks
cat > roles/mynewrole/tasks/main.yml <<EOF
---
- name: Do something
  debug:
    msg: "Hello from new role"
EOF

# Add to playbook
nano playbook.yml
# Add "- role: mynewrole" under roles:
```

## 🔍 Debugging & Troubleshooting

### Check Ansible Version
```bash
ansible --version
# Should be 2.10+ for osx_defaults module
```

### Verify Collection Installed
```bash
ansible-galaxy collection list | grep community.general
```

### Verbose Output
```bash
# Show what's happening
ansible-playbook playbook.yml -v

# Very verbose (shows module args)
ansible-playbook playbook.yml -vv

# Debug level (shows everything)
ansible-playbook playbook.yml -vvv
```

### Check Syntax
```bash
ansible-playbook playbook.yml --syntax-check
```

### List Tasks
```bash
ansible-playbook playbook.yml --list-tasks
```

### List Tags
```bash
ansible-playbook playbook.yml --list-tags
```

### Dry Run (Check Mode)
```bash
# See what would change without changing it
ansible-playbook playbook.yml --check --diff
```

## 🆚 Ansible vs Other Tools

### vs Chezmoi
**Ansible Advantages:**
- Industry-standard IaC tool
- Powerful modules (1000s available)
- Can manage entire infrastructure
- Great for teams/fleets
- Resume-worthy skill

**Chezmoi Advantages:**
- Purpose-built for dotfiles
- Simpler for personal use
- Single binary, no dependencies
- 1Password integration
- Faster execution

### vs Bash Scripts
**Ansible Advantages:**
- Idempotent by design
- Declarative (what, not how)
- Cross-platform modules
- Better error handling
- Testable and versioned

**Bash Advantages:**
- No dependencies
- Direct and simple
- Easier for quick hacks

## 📚 Learning Resources

### Official Documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Jinja2 Templating](https://jinja.palletsprojects.com/)
- [community.general Collection](https://docs.ansible.com/ansible/latest/collections/community/general/)

### Tutorials
- [Ansible for DevOps](https://www.ansiblefordevops.com/) - Free book by Jeff Geerling
- [Learn Ansible in Y Minutes](https://learnxinyminutes.com/docs/ansible/)
- [YouTube: Ansible 101 by Jeff Geerling](https://www.youtube.com/watch?v=goclfp6a2IQ)

### Example Repos
- [Jeff Geerling's dotfiles](https://github.com/geerlingguy/ansible-role-dotfiles)
- [sloria's dotfiles](https://github.com/sloria/dotfiles)

## 🎓 Next Steps

### For Learning
1. **Understand the structure** - Read through each role's tasks
2. **Modify variables** - Change packages, settings in `group_vars/all.yml`
3. **Run with --check** - See what would happen
4. **Apply and observe** - Watch Ansible work
5. **Create new role** - Practice by adding your own
6. **Use on VMs** - Set up lab environment to practice

### For Production Use
1. **Fork this repo** - Make it your own
2. **Customize variables** - Add your info, packages, settings
3. **Test in VM** - Verify everything works
4. **Add to dotfiles repo** - Merge into main dotfiles
5. **Document** - Add notes about your customizations
6. **Maintain** - Update packages, settings as needed

### Advanced Topics
- **Ansible Vault** - Encrypt sensitive data
- **Dynamic Inventory** - Manage multiple machines
- **Roles on Galaxy** - Reusable roles from community
- **CI/CD Integration** - Test changes automatically
- **Remote Execution** - Configure VMs/servers via SSH

## 💡 Tips & Best Practices

### Always Use --check First
```bash
ansible-playbook playbook.yml --check --diff
```

### Use Tags for Speed
```bash
# Only run specific parts
ansible-playbook playbook.yml --tags zsh,git
```

### Keep Variables Organized
- Common settings in `group_vars/all.yml`
- Secrets in Ansible Vault
- Host-specific in `inventory.yml`

### Make Tasks Idempotent
```yaml
# Good - checks if needed
- name: Create directory
  file:
    path: ~/.config
    state: directory

# Bad - runs every time
- name: Create directory
  command: mkdir -p ~/.config
```

### Use Modules Over Commands
```yaml
# Good - idempotent, safe
- name: Install package
  homebrew:
    name: git
    state: present

# Bad - not idempotent
- name: Install package
  command: brew install git
```

## 🚀 Professional Development

### Skills You'll Learn
- **Ansible**: Core DevOps tool
- **YAML**: Configuration language
- **Jinja2**: Templating
- **IaC Principles**: Declarative configuration
- **Idempotency**: Safe repeatability
- **Modules**: Reusable components

### Resume Keywords
- Infrastructure as Code (IaC)
- Ansible playbooks and roles
- Configuration management
- Automation
- DevOps practices
- YAML/Jinja2

### Career Applications
- Configure development environments
- Manage server fleets
- Deploy applications
- Automate DevOps tasks
- Team standardization
- Compliance/security enforcement

## 🔗 Related Files

- `../chezmoi-poc/` - Chezmoi alternative for comparison
- `../chezmoi-poc/ANSIBLE_COMPARISON.md` - Side-by-side comparison
- Original dotfiles in `../zsh/`, `../git/`, etc.

---

**Questions? Issues? Suggestions?**

This POC is a learning tool. Experiment, break things, and learn how Ansible works!
