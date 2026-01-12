# Chezmoi vs Ansible: Side-by-Side Comparison

Both POCs are available in this repository for you to compare and learn from.

## 📁 Directory Comparison

### Chezmoi Structure
```
chezmoi-poc/
├── .chezmoi.toml.tmpl                    # Configuration & variables
├── .chezmoiignore                         # Files to skip
├── dot_zshrc.tmpl                         # Template → ~/.zshrc
├── dot_gitconfig.tmpl                     # Template → ~/.gitconfig
├── dot_tmux.conf                          # Static → ~/.tmux.conf
├── Brewfile.tmpl                          # Homebrew packages
├── run_once_before_install-packages.sh.tmpl    # Setup script
├── run_once_after_install-plugins.sh.tmpl      # Plugin script
├── run_once_after_configure-macos.sh.tmpl      # macOS settings
└── run_onchange_after_brewfile-update.sh.tmpl  # Auto-update
```

### Ansible Structure
```
ansible-poc/
├── ansible.cfg                           # Ansible config
├── inventory.yml                         # Hosts definition
├── playbook.yml                          # Main orchestration
├── group_vars/all.yml                    # All variables
├── requirements.yml                      # Ansible collections
└── roles/                                # Organized by function
    ├── homebrew/tasks/main.yml          # Package management
    ├── zsh/{tasks,templates,files}/     # Shell config
    ├── git/{tasks,templates}/           # Git config
    ├── tmux/{tasks,files}/              # Tmux config
    ├── neovim/tasks/                    # Editor config
    └── macos/tasks/                     # macOS settings
```

## 🎯 Philosophy

### Chezmoi
- **File-centric**: Files are the primary abstraction
- **Templates**: Go templates generate configs
- **Scripts**: Bash scripts for complex operations
- **Single tool**: One binary does everything

### Ansible
- **Task-centric**: Tasks are the primary abstraction
- **Declarative**: Describe desired state
- **Modules**: Reusable components for operations
- **Industry standard**: Used for servers, infrastructure

## 💻 Templating Comparison

### Platform Detection

**Chezmoi (Go templates):**
```go
{{- if eq .chezmoi.os "darwin" }}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{{- else if eq .chezmoi.os "linux" }}
# Linux-specific
export PATH="/usr/local/bin:$PATH"
{{- end }}
```

**Ansible (Jinja2 templates):**
```jinja2
{% if ansible_os_family == "Darwin" %}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{% else %}
# Linux-specific
export PATH="/usr/local/bin:$PATH"
{% endif %}
```

### Variables

**Chezmoi (.chezmoi.toml.tmpl):**
```toml
[data]
    name = "Your Name"
    email = "your@email.com"
    work = false

# Use in templates:
# {{ .name }}
# {{ .email }}
# {{ .work }}
```

**Ansible (group_vars/all.yml):**
```yaml
git_user_name: "Your Name"
git_user_email: "your@email.com"
is_work_machine: false

# Use in templates:
# {{ git_user_name }}
# {{ git_user_email }}
# {{ is_work_machine }}
```

## 📦 Package Management

### Chezmoi Approach

**Brewfile.tmpl:**
```ruby
{{- if eq .chezmoi.os "darwin" -}}
brew "git"
brew "starship"
brew "fzf"
{{- if .work }}
brew "kubectl"
{{- end }}
{{- end -}}
```

**Plus script:**
```bash
#!/bin/bash
{{- if eq .chezmoi.os "darwin" }}
brew bundle --global --no-lock
{{- end }}
```

### Ansible Approach

**group_vars/all.yml:**
```yaml
homebrew_packages:
  - git
  - starship
  - fzf

homebrew_work_packages:
  - kubectl
```

**roles/homebrew/tasks/main.yml:**
```yaml
- name: Install Homebrew packages
  community.general.homebrew:
    name: "{{ homebrew_packages }}"
    state: present

- name: Install work packages
  community.general.homebrew:
    name: "{{ homebrew_work_packages }}"
    state: present
  when: is_work_machine | bool
```

## ⚙️ macOS Settings

### Chezmoi Approach

**run_once_after_configure-macos.sh.tmpl:**
```bash
{{- if eq .chezmoi.os "darwin" }}
#!/bin/bash
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.dock autohide -bool true
killall Finder Dock
{{- end }}
```

### Ansible Approach

**group_vars/all.yml:**
```yaml
macos_settings:
  finder:
    - { domain: "com.apple.finder", key: "ShowPathbar", type: "bool", value: "true" }
  dock:
    - { domain: "com.apple.dock", key: "autohide", type: "bool", value: "true" }
```

**roles/macos/tasks/main.yml:**
```yaml
- name: Configure Finder settings
  community.general.osx_defaults:
    domain: "{{ item.domain }}"
    key: "{{ item.key }}"
    type: "{{ item.type }}"
    value: "{{ item.value }}"
  loop: "{{ macos_settings.finder }}"
  notify: restart finder
```

## 🔄 Execution Comparison

### Chezmoi

```bash
# Initialize
chezmoi init --apply https://github.com/user/dots.git

# Or from local source
chezmoi init --source ~/dots/chezmoi-poc

# Preview changes
chezmoi diff

# Apply changes
chezmoi apply -v

# Update one file
chezmoi apply ~/.zshrc
```

### Ansible

```bash
# Clone repo
git clone https://github.com/user/dots.git ~/dots
cd ~/dots/ansible-poc

# Install dependencies
ansible-galaxy collection install -r requirements.yml

# Preview changes
ansible-playbook playbook.yml --check --diff

# Apply all
ansible-playbook playbook.yml

# Update one role
ansible-playbook playbook.yml --tags zsh
```

## 🎓 Learning Curve

### Chezmoi
**Easier to learn:**
- Simpler concept: files + templates + scripts
- Go templates (basic conditionals, loops)
- Bash scripts for complex logic
- Less configuration needed

**Time to productivity:** ~2-4 hours

### Ansible
**Moderate learning curve:**
- Must understand: playbooks, roles, tasks, modules, variables
- YAML syntax and structure
- Jinja2 templating
- Ansible-specific concepts (handlers, facts, etc.)

**Time to productivity:** ~8-16 hours

## 💪 Strengths Comparison

### Chezmoi Strengths

✅ **Simpler for personal dotfiles**
- Purpose-built tool
- Less abstraction layers
- Faster execution
- Single binary, portable

✅ **1Password integration**
- Native support
- Easy secret management
- `onepasswordRead` function

✅ **Smart file watching**
- `run_onchange_` runs when files change
- Hash-based change detection
- Efficient updates

✅ **Cross-machine sync**
- Easy to pull/push changes
- Built-in diff tools
- State management

### Ansible Strengths

✅ **Industry standard**
- Resume-worthy skill
- Used in enterprises
- Huge community
- Tons of resources

✅ **Powerful modules**
- 1000s of modules available
- Well-tested and maintained
- Idempotent by design
- Cross-platform abstractions

✅ **Scalability**
- Manage fleets of machines
- Remote execution via SSH
- Inventory management
- Group configurations

✅ **Reusability**
- Roles shareable on Galaxy
- Modular design
- DRY principles
- Team collaboration

## 📊 Feature Matrix

| Feature | Chezmoi | Ansible |
|---------|---------|---------|
| **Templating** | Go templates | Jinja2 |
| **Variables** | TOML/JSON | YAML |
| **Platform detection** | ✅ Excellent | ✅ Excellent |
| **Package mgmt** | Shell scripts | Native modules |
| **1Password** | ✅ Native | ⚠️ Manual |
| **Secrets** | ✅ Built-in | ⚠️ Vault/external |
| **macOS settings** | Shell scripts | ✅ osx_defaults |
| **Idempotency** | ⚠️ Manual | ✅ Built-in |
| **Dry run** | ✅ `diff` | ✅ `--check` |
| **Speed** | ✅ Fast | ⚠️ Slower |
| **Dependencies** | None | Python + Ansible |
| **Remote exec** | ❌ No | ✅ Yes |
| **Multi-machine** | ⚠️ Limited | ✅ Excellent |
| **Learning curve** | 🟢 Low | 🟡 Medium |
| **Resume value** | 🟡 Niche | ✅ High |
| **Community** | Growing | Huge |

## 🎯 Use Case Recommendations

### Choose Chezmoi If:

- ✅ Personal dotfiles only
- ✅ Want simplest solution
- ✅ Use 1Password for secrets
- ✅ Don't need remote execution
- ✅ Prefer Go ecosystem
- ✅ Want fast, lightweight tool

### Choose Ansible If:

- ✅ Learning for career
- ✅ Manage multiple machines
- ✅ Need enterprise features
- ✅ Team environment
- ✅ Complex system configuration
- ✅ Want transferable skills

### Use Both If:

- ✅ **Chezmoi**: Daily dotfiles management
- ✅ **Ansible**: Learning & lab environments
- ✅ Keep separate repos
- ✅ Best of both worlds

## 💡 Real-World Workflow

### Chezmoi Daily Use
```bash
# Edit config in editor
vim ~/.zshrc

# See what changed
chezmoi diff

# Add changes to source
chezmoi add ~/.zshrc

# Commit and push
chezmoi cd
git commit -am "Update zsh config"
git push

# Apply on another machine
chezmoi update
```

### Ansible Daily Use
```bash
# Edit template in repo
vim ~/dots/ansible-poc/roles/zsh/templates/zshrc.j2

# Test changes
ansible-playbook playbook.yml --tags zsh --check

# Apply changes
ansible-playbook playbook.yml --tags zsh

# Commit and push
git commit -am "Update zsh config"
git push

# Apply on another machine
git pull
ansible-playbook playbook.yml --tags zsh
```

## 🚀 New Machine Setup

### Chezmoi
```bash
# One command!
chezmoi init --apply https://github.com/user/dots.git

# Everything installed:
# ✅ Dotfiles
# ✅ Packages (via scripts)
# ✅ Plugins
# ✅ Settings
```

### Ansible
```bash
# Clone
git clone https://github.com/user/dots.git ~/dots
cd ~/dots/ansible-poc

# Install Ansible (if needed)
brew install ansible  # or apt install ansible

# Install collections
ansible-galaxy collection install -r requirements.yml

# Apply
ansible-playbook playbook.yml

# Everything automated:
# ✅ Dotfiles
# ✅ Packages (via modules)
# ✅ Plugins
# ✅ Settings
```

## 📈 Skill Development Path

### Chezmoi Path
1. Learn Go template basics
2. Understand file naming (dot_, run_once_, etc.)
3. Master scripts for complex logic
4. Learn 1Password integration
5. Optimize with change detection

**Outcome:** Efficient dotfile management

### Ansible Path
1. Learn YAML syntax
2. Understand playbooks & roles
3. Master Jinja2 templating
4. Learn modules & collections
5. Practice idempotent tasks
6. Expand to VMs/servers

**Outcome:** DevOps career skills

## 💰 Investment vs Return

### Chezmoi
- **Time investment:** Low (2-4 hours)
- **Maintenance:** Low
- **Personal productivity:** High
- **Career value:** Medium
- **Flexibility:** Medium

### Ansible
- **Time investment:** Medium (8-16 hours)
- **Maintenance:** Medium
- **Personal productivity:** High
- **Career value:** Very High
- **Flexibility:** Very High

## 🎓 Recommended Approach

### For You (Heavy 1Password user, Career development)

**Week 1-2: Test Both POCs**
```bash
# Try Chezmoi
cd ~/dots/chezmoi-poc
./TEST.sh

# Try Ansible
cd ~/dots/ansible-poc
./TEST.sh
```

**Week 3-4: Choose & Migrate**

**Option A: Chezmoi for Daily Use**
- Quick, efficient
- 1Password integration
- Low maintenance

**Option B: Ansible for Learning**
- Separate repo: `ansible-dotfiles`
- Practice on VMs
- Build DevOps skills

**Option C: Both! (Recommended)**
- **Production**: Chezmoi for personal dotfiles
- **Learning**: Ansible on lab machines
- Best of both worlds

## 📚 Resources

### Chezmoi
- [Official Docs](https://www.chezmoi.io/)
- [GitHub](https://github.com/twpayne/chezmoi)
- [1Password Integration](https://www.chezmoi.io/user-guide/password-managers/1password/)

### Ansible
- [Official Docs](https://docs.ansible.com/)
- [Ansible for DevOps Book](https://www.ansiblefordevops.com/)
- [Jeff Geerling's YouTube](https://www.youtube.com/c/JeffGeerling)
- [Ansible Galaxy](https://galaxy.ansible.com/)

## 🔗 Try Both POCs

Both are ready to test in this repo:
```bash
# Chezmoi POC
cd ~/dots/chezmoi-poc
cat README.md
cat QUICKSTART.md
./TEST.sh

# Ansible POC
cd ~/dots/ansible-poc
cat README.md
cat QUICKSTART.md
./TEST.sh
```

---

**The best choice?** Try both and see which fits your workflow! You can even use both for different purposes.
