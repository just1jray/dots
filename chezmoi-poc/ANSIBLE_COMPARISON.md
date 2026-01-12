# Ansible vs Chezmoi Comparison

This document shows how the same dotfile management tasks look in Ansible vs Chezmoi.

## Directory Structure Comparison

### Chezmoi Structure
```
~/.local/share/chezmoi/
├── .chezmoi.toml.tmpl              # Config
├── .chezmoiignore                   # Ignore file
├── dot_zshrc.tmpl                   # Template → ~/.zshrc
├── dot_gitconfig.tmpl               # Template → ~/.gitconfig
├── dot_tmux.conf                    # Static → ~/.tmux.conf
├── Brewfile.tmpl                    # Homebrew packages
├── dot_config/
│   └── starship/
│       └── starship.toml           # → ~/.config/starship/starship.toml
└── run_once_before_install-packages.sh.tmpl
```

### Ansible Structure
```
ansible-dotfiles/
├── ansible.cfg                      # Ansible config
├── inventory.yml                    # Hosts (usually just localhost)
├── playbook.yml                     # Main entry point
├── group_vars/
│   └── all.yml                      # Variables
├── roles/
│   ├── homebrew/
│   │   └── tasks/main.yml          # Install Homebrew packages
│   ├── zsh/
│   │   ├── tasks/main.yml          # Install & configure zsh
│   │   ├── templates/
│   │   │   └── zshrc.j2            # Jinja2 template
│   │   └── files/
│   │       └── aliases             # Static files
│   ├── git/
│   │   ├── tasks/main.yml
│   │   └── templates/
│   │       └── gitconfig.j2
│   └── tmux/
│       ├── tasks/main.yml
│       └── files/
│           └── tmux.conf
```

## Example 1: Managing gitconfig

### Chezmoi: `dot_gitconfig.tmpl`
```ini
[user]
    name = {{ .name }}
    email = {{ .email }}

{{- if eq .chezmoi.os "darwin" }}
[credential]
    helper = osxkeychain
{{- else }}
[credential]
    helper = cache --timeout=3600
{{- end }}
```

### Ansible: `roles/git/templates/gitconfig.j2`
```ini
[user]
    name = {{ git_user_name }}
    email = {{ git_user_email }}

{% if ansible_os_family == "Darwin" %}
[credential]
    helper = osxkeychain
{% else %}
[credential]
    helper = cache --timeout=3600
{% endif %}
```

**Plus `roles/git/tasks/main.yml`:**
```yaml
---
- name: Create gitconfig symlink
  file:
    src: "{{ playbook_dir }}/roles/git/templates/gitconfig.j2"
    dest: "{{ ansible_env.HOME }}/.gitconfig"
    state: link
```

## Example 2: Installing Homebrew Packages

### Chezmoi: `Brewfile.tmpl` + Script
```ruby
# Brewfile.tmpl
{{- if eq .chezmoi.os "darwin" -}}
brew "git"
brew "starship"
brew "neovim"
{{- if .work }}
brew "kubectl"
{{- end }}
{{- end -}}
```

**Plus `run_onchange_after_brewfile-update.sh.tmpl`:**
```bash
#!/bin/bash
# Hash: {{ include "Brewfile.tmpl" | sha256sum }}
{{- if eq .chezmoi.os "darwin" }}
brew bundle --global --no-lock
{{- end }}
```

### Ansible: `roles/homebrew/tasks/main.yml`
```yaml
---
- name: Install Homebrew packages
  community.general.homebrew:
    name:
      - git
      - starship
      - neovim
    state: present
  when: ansible_os_family == "Darwin"

- name: Install work packages
  community.general.homebrew:
    name:
      - kubectl
    state: present
  when:
    - ansible_os_family == "Darwin"
    - is_work_machine | bool
```

## Example 3: Platform-Specific Configuration

### Chezmoi: `dot_zshrc.tmpl`
```bash
# Common settings
export EDITOR=nvim

{{- if eq .chezmoi.os "darwin" }}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{{- else if eq .chezmoi.os "linux" }}
# Linux-specific
export PATH="/usr/local/bin:$PATH"
{{- end }}

{{- if .work }}
# Work-specific
source ~/.config/zsh/profile-work
{{- end }}
```

### Ansible: `roles/zsh/templates/zshrc.j2`
```bash
# Common settings
export EDITOR=nvim

{% if ansible_os_family == "Darwin" %}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{% elif ansible_os_family == "Debian" %}
# Linux-specific
export PATH="/usr/local/bin:$PATH"
{% endif %}

{% if is_work_machine %}
# Work-specific
source ~/.config/zsh/profile-work
{% endif %}
```

## Example 4: Complete Playbook

### Chezmoi: Single Command
```bash
# Everything automated via run scripts
chezmoi init --apply https://github.com/just1jray/dots.git
```

### Ansible: `playbook.yml`
```yaml
---
- name: Configure dotfiles
  hosts: localhost
  connection: local

  vars:
    git_user_name: "Your Name"
    git_user_email: "your@email.com"
    is_work_machine: false

  pre_tasks:
    - name: Detect if work machine
      set_fact:
        is_work_machine: "{{ ansible_hostname is search('work') }}"

  roles:
    - homebrew      # Install packages first
    - zsh           # Configure zsh
    - git           # Configure git
    - tmux          # Configure tmux
    - neovim        # Configure neovim
    - macos         # macOS settings (when applicable)

# Run with:
# ansible-playbook playbook.yml
```

## Example 5: macOS System Settings

### Chezmoi: `run_once_after_configure-macos.sh.tmpl`
```bash
{{- if eq .chezmoi.os "darwin" }}
#!/bin/bash
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.dock autohide -bool true
killall Finder Dock
{{- end }}
```

### Ansible: `roles/macos/tasks/main.yml`
```yaml
---
- name: Configure Finder to show path bar
  community.general.osx_defaults:
    domain: com.apple.finder
    key: ShowPathbar
    type: bool
    value: true
  when: ansible_os_family == "Darwin"
  notify: restart finder

- name: Configure Dock to auto-hide
  community.general.osx_defaults:
    domain: com.apple.dock
    key: autohide
    type: bool
    value: true
  when: ansible_os_family == "Darwin"
  notify: restart dock

# Handlers
handlers:
  - name: restart finder
    command: killall Finder

  - name: restart dock
    command: killall Dock
```

## Pros/Cons Summary

### Chezmoi
**Pros:**
- Simpler for dotfiles-only management
- Single binary, no dependencies
- Built specifically for dotfiles
- Templates and scripts in same directory as configs
- One command to apply everything

**Cons:**
- Less powerful for system configuration
- Shell scripts for complex logic
- Smaller ecosystem than Ansible
- Less resume-worthy

### Ansible
**Pros:**
- Industry-standard IaC tool
- Great for professional development
- Powerful modules (1000s available)
- Can manage entire infrastructure, not just dotfiles
- Idempotent by design
- Great for teams/fleets
- Very resume-worthy skill

**Cons:**
- More complex setup
- Requires Python
- More verbose (YAML + templates + tasks)
- Overkill for personal dotfiles
- Slower execution

## Which Should You Choose?

### Choose Chezmoi If:
- Focus is only on personal dotfiles
- Want simplest solution
- Need 1Password integration
- Don't need to learn Ansible for work

### Choose Ansible If:
- Want to learn Ansible for career development
- Manage multiple machines/VMs
- Need to configure system settings extensively
- Planning to use for work projects
- Want industry-standard tool on resume

### Use Both?
You could:
1. **Chezmoi for dotfiles** - Day-to-day personal config management
2. **Ansible for learning** - Set up lab VMs, practice DevOps skills
3. Keep them separate - Best of both worlds

## Quick Start: Learning Ansible

### Minimal Ansible Dotfiles Setup
```bash
# Install
brew install ansible

# Create structure
mkdir -p ansible-dotfiles/roles/dotfiles/{tasks,files}
cd ansible-dotfiles

# Create inventory
cat > inventory.yml <<EOF
all:
  hosts:
    localhost:
      ansible_connection: local
EOF

# Create playbook
cat > playbook.yml <<EOF
---
- hosts: localhost
  roles:
    - dotfiles
EOF

# Create role
cat > roles/dotfiles/tasks/main.yml <<EOF
---
- name: Symlink zshrc
  file:
    src: "{{ playbook_dir }}/roles/dotfiles/files/zshrc"
    dest: "{{ ansible_env.HOME }}/.zshrc"
    state: link

- name: Install Homebrew packages
  community.general.homebrew:
    name:
      - starship
      - fzf
    state: present
  when: ansible_os_family == "Darwin"
EOF

# Copy your dotfiles
cp ~/.zshrc roles/dotfiles/files/zshrc

# Run it
ansible-playbook -i inventory.yml playbook.yml
```

### Learning Path
1. Start with simple file management (symlinking dotfiles)
2. Add templating (platform-specific configs)
3. Add package management (homebrew module)
4. Add macOS settings (osx_defaults module)
5. Expand to full system configuration
6. Use on VMs/remote machines to practice

### Resources
- [Ansible Documentation](https://docs.ansible.com/)
- [Jeff Geerling's dotfiles](https://github.com/geerlingguy/ansible-role-dotfiles) - Great example
- [Ansible for DevOps](https://www.ansiblefordevops.com/) - Excellent book
- [YouTube: Ansible 101 by Jeff Geerling](https://www.youtube.com/watch?v=goclfp6a2IQ)

## Recommendation for You

Given your situation:

1. **For production dotfiles**: Use **Chezmoi**
   - Faster, simpler, purpose-built
   - 1Password integration is excellent
   - Less maintenance overhead

2. **For learning**: Set up **Ansible** in parallel
   - Create separate ansible-dotfiles repo
   - Practice on VMs
   - Build resume skills
   - Can reference when needed for work

3. **Migration path**:
   ```bash
   # Week 1: Try Chezmoi POC
   chezmoi init --source ~/dots/chezmoi-poc

   # Week 2: Migrate to Chezmoi if you like it
   # (Use POC as guide)

   # Week 3: Start Ansible learning project
   # Create ansible-dotfiles for practice/learning
   # Don't try to replace Chezmoi, just learn Ansible
   ```

This gives you both productivity (Chezmoi) and professional development (Ansible).
