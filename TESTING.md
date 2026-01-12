# Testing Guide: Parallels, Docker, and VMs

Complete guide for safely testing both Chezmoi and Ansible POCs in isolated environments.

## 🖥️ Testing with Parallels Desktop (macOS)

Parallels is perfect for testing since it's easy to snapshot and restore VMs.

### Prerequisites
- Parallels Desktop installed on Mac
- macOS or Linux VM image (Ubuntu recommended for Linux testing)

### Setup: Create Test VM

**Option 1: macOS VM** (for full macOS testing)
```bash
# Create new macOS VM in Parallels
# File → New → macOS
# Follow wizard to install macOS

# Recommended specs:
# - 4 GB RAM minimum (8 GB better)
# - 40 GB disk
# - Shared folders: Enable (for easy file access)
```

**Option 2: Ubuntu VM** (faster, lighter)
```bash
# Download Ubuntu Server or Desktop
# https://ubuntu.com/download

# In Parallels:
# File → New → Install from Image
# Select Ubuntu ISO
# Follow wizard

# Recommended specs:
# - 2-4 GB RAM
# - 20 GB disk
# - Shared folders: Enable
```

### Testing Process

**1. Snapshot Before Testing**
```bash
# In Parallels UI:
# Actions → Take Snapshot
# Name: "Clean Install - Before Dotfiles"
# This allows instant rollback if something goes wrong
```

**2. Transfer Files to VM**

**Method A: Shared Folders** (Easiest)
```bash
# On Mac (your host):
# Parallels → Configure → Options → Sharing → Share Mac folders
# Enable "Share Mac home folder with Linux"

# In VM:
cd /media/psf/Home/dots  # macOS shared folder
# or
cd ~/dots  # if synced
```

**Method B: Git Clone** (Cleanest)
```bash
# In VM:
git clone https://github.com/just1jray/dots.git ~/dots
cd ~/dots
git checkout claude/stow-dotfiles-evaluation-42Mqb
```

**Method C: SCP** (Manual)
```bash
# On Mac:
# Get VM IP from Parallels
# In VM: ip addr show

# Transfer files
scp -r ~/dots user@VM_IP:~/

# In VM:
cd ~/dots
```

**3. Test Chezmoi POC**

```bash
# In VM (Ubuntu example):
cd ~/dots/chezmoi-poc

# Install Chezmoi
curl -sfL https://git.io/chezmoi | sh
# Or: brew install chezmoi (if macOS VM)

# Preview changes
./TEST.sh
# Select option 1 (dry run)

# Apply if looks good
./TEST.sh
# Select option 5 (apply)

# Verify
ls -la ~/ | grep -E '\.(zshrc|gitconfig|tmux.conf)'
```

**4. Test Ansible POC**

```bash
# In VM:
cd ~/dots/ansible-poc

# Install Ansible (Ubuntu)
sudo apt update
sudo apt install -y ansible python3-pip

# Or macOS VM:
brew install ansible

# Install collections
ansible-galaxy collection install -r requirements.yml

# Customize variables
nano group_vars/all.yml
# Change git_user_name and git_user_email

# Preview changes
./TEST.sh
# Select option 4 (dry run)

# Apply if looks good
./TEST.sh
# Select option 7 (apply)

# Verify
which starship fzf zoxide
ls -la ~/.zshrc ~/.gitconfig
```

**5. Restore from Snapshot** (if needed)

```bash
# If something goes wrong:
# In Parallels:
# Actions → Revert to Snapshot
# Select: "Clean Install - Before Dotfiles"
#
# VM instantly restored to clean state!
# Try again with modifications
```

### Best Practices with Parallels

**Create Multiple Snapshots:**
```
Snapshot 1: "Clean macOS"
Snapshot 2: "After Chezmoi Install"
Snapshot 3: "After Ansible Install"
Snapshot 4: "Full Configuration Applied"
```

**Linked Clones for Multiple Tests:**
```bash
# In Parallels:
# File → Clone
# Select "Linked Clone" (saves disk space)
# Name: "Dotfiles Test - Chezmoi"
#
# Create another:
# Name: "Dotfiles Test - Ansible"
#
# Test different approaches in parallel!
```

**Network Settings:**
```bash
# Shared Network (default) - easier, VM shares Mac's network
# Bridged Network - VM gets own IP, acts like separate machine
# Host-Only - Isolated network, most secure for testing
```

---

## 🐳 Testing with Docker

Docker is fastest for quick, disposable tests. Perfect for Linux testing.

### Prerequisites
```bash
# Install Docker Desktop for Mac
# https://www.docker.com/products/docker-desktop

# Verify installation
docker --version
docker run hello-world
```

### Understanding Docker Commands

Let's break down each command step-by-step:

#### Basic Structure
```bash
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

- `docker run` - Create and start a new container
- `[OPTIONS]` - Flags to configure the container
- `IMAGE` - The base image to use (e.g., ubuntu:22.04)
- `[COMMAND]` - Command to run inside container
- `[ARG...]` - Arguments for the command

### Testing Chezmoi in Docker

**Basic Test:**
```bash
docker run -it --rm ubuntu:22.04 bash
```

**What this does:**
- `docker run` - Start new container
- `-it` - Interactive terminal
  - `-i` = Keep STDIN open (you can type)
  - `-t` = Allocate pseudo-TTY (terminal emulator)
- `--rm` - Automatically remove container when it exits
  - **Why:** Cleanup, don't leave stopped containers
- `ubuntu:22.04` - Use Ubuntu 22.04 LTS image
  - Downloads automatically if not cached
- `bash` - Run bash shell inside container

**Inside the container:**
```bash
# Now you're in an Ubuntu container!

# Install dependencies
apt update
apt install -y git curl

# Install Chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Clone your dotfiles
git clone https://github.com/just1jray/dots.git ~/dots
cd ~/dots
git checkout claude/stow-dotfiles-evaluation-42Mqb

# Test Chezmoi
cd chezmoi-poc
/root/.local/bin/chezmoi init --source .
/root/.local/bin/chezmoi diff

# Exit when done (container is deleted automatically)
exit
```

**Advanced Docker Test with Volume Mount:**
```bash
docker run -it --rm \
  -v ~/dots:/workspace \
  ubuntu:22.04 \
  bash
```

**What the new options do:**
- `-v ~/dots:/workspace` - Volume mount
  - **Format:** `HOST_PATH:CONTAINER_PATH`
  - **~/dots** - Your Mac's dots directory
  - **:/workspace** - Mounted at /workspace in container
  - **Why:** Access files without git clone, changes sync instantly

**Inside container with volume:**
```bash
cd /workspace/chezmoi-poc
ls  # See your files from Mac!

apt update && apt install -y git curl
sh -c "$(curl -fsLS get.chezmoi.io)"

/root/.local/bin/chezmoi init --source .
/root/.local/bin/chezmoi diff
```

### Testing Ansible in Docker

**Basic Ansible Test:**
```bash
docker run -it --rm \
  -v ~/dots:/workspace \
  ubuntu:22.04 \
  bash -c "
    apt update &&
    apt install -y ansible git &&
    cd /workspace/ansible-poc &&
    ansible-galaxy collection install -r requirements.yml &&
    ansible-playbook playbook.yml --check --diff
  "
```

**Breaking down this complex command:**

1. **`docker run -it --rm`** - Interactive, auto-remove
2. **`-v ~/dots:/workspace`** - Mount your dots folder
3. **`ubuntu:22.04`** - Base image
4. **`bash -c "..."`** - Run bash with these commands:
   - `apt update` - Update package lists
   - `apt install -y ansible git` - Install Ansible and Git
     - `-y` = Auto-yes to prompts
   - `cd /workspace/ansible-poc` - Go to mounted directory
   - `ansible-galaxy collection install -r requirements.yml` - Install Ansible collections
   - `ansible-playbook playbook.yml --check --diff` - DRY RUN playbook
     - `--check` = Preview only, don't apply
     - `--diff` = Show what would change

**Interactive Ansible Test:**
```bash
docker run -it --rm \
  -v ~/dots:/workspace \
  ubuntu:22.04 \
  bash
```

**Inside container:**
```bash
# Install Ansible
apt update
apt install -y ansible git sudo

# Go to your dotfiles
cd /workspace/ansible-poc

# Install collections
ansible-galaxy collection install -r requirements.yml

# Edit variables (optional)
apt install -y nano
nano group_vars/all.yml
# Change git_user_name and git_user_email

# Dry run
ansible-playbook playbook.yml --check --diff

# Apply for real (inside container, safe!)
ansible-playbook playbook.yml

# Verify
which starship fzf  # Probably not installed (some packages fail in Docker)
ls -la ~/.zshrc ~/.gitconfig  # But configs are deployed!

# Exit (container destroyed)
exit
```

### Docker Multi-Platform Testing

**Test on Different Ubuntu Versions:**
```bash
# Ubuntu 22.04 (LTS)
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash

# Ubuntu 20.04 (older LTS)
docker run -it --rm -v ~/dots:/workspace ubuntu:20.04 bash

# Debian 12
docker run -it --rm -v ~/dots:/workspace debian:12 bash

# Rocky Linux (RHEL-like)
docker run -it --rm -v ~/dots:/workspace rockylinux:9 bash
```

**Test Different Architectures:**
```bash
# ARM64 (Apple Silicon simulation on Intel, or vice versa)
docker run -it --rm --platform linux/arm64 \
  -v ~/dots:/workspace \
  ubuntu:22.04 bash

# AMD64 (Intel/AMD)
docker run -it --rm --platform linux/amd64 \
  -v ~/dots:/workspace \
  ubuntu:22.04 bash
```

### Docker Compose for Repeatable Tests

Create `docker-compose.yml` in `~/dots`:
```yaml
version: '3.8'

services:
  chezmoi-test:
    image: ubuntu:22.04
    volumes:
      - .:/workspace
    working_dir: /workspace/chezmoi-poc
    stdin_open: true
    tty: true
    command: bash

  ansible-test:
    image: ubuntu:22.04
    volumes:
      - .:/workspace
    working_dir: /workspace/ansible-poc
    stdin_open: true
    tty: true
    command: bash
```

**Use Docker Compose:**
```bash
cd ~/dots

# Start Chezmoi test container
docker-compose run chezmoi-test

# Or Ansible test container
docker-compose run ansible-test

# Cleanup when done
docker-compose down
```

### Docker Limitations

**What DOESN'T work in Docker:**
- ❌ Homebrew installation (macOS only)
- ❌ macOS system settings (`defaults write`)
- ❌ GUI applications
- ❌ Some system services (systemd limited)
- ❌ Changing default shell permanently

**What DOES work:**
- ✅ Testing Ansible playbook syntax
- ✅ Testing template rendering
- ✅ Testing task logic
- ✅ Installing Linux packages (apt)
- ✅ Deploying dotfiles
- ✅ Testing scripts

**Docker is best for:**
- Quick Linux testing
- CI/CD pipelines
- Syntax validation
- Template testing
- Disposable environments

---

## 🔄 Testing Workflow Comparison

### Parallels VM
**Best for:**
- ✅ Full system testing
- ✅ macOS-specific features
- ✅ Homebrew testing
- ✅ System settings testing
- ✅ Realistic environment

**Workflow:**
```
Create VM → Snapshot → Test → Restore → Repeat
Time: ~15 min per test
```

### Docker Container
**Best for:**
- ✅ Quick Linux testing
- ✅ Ansible syntax validation
- ✅ Template rendering tests
- ✅ Disposable tests
- ✅ CI/CD integration

**Workflow:**
```
Run container → Test → Exit (auto-cleanup)
Time: ~2 min per test
```

---

## 🧪 Recommended Testing Strategy

### Phase 1: Quick Validation (Docker)
```bash
# Test Ansible syntax (30 seconds)
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash -c "
  apt update -qq &&
  apt install -y -qq ansible &&
  cd /workspace/ansible-poc &&
  ansible-playbook playbook.yml --syntax-check
"

# Test template rendering (1 minute)
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash -c "
  apt update -qq &&
  apt install -y -qq ansible git &&
  cd /workspace/ansible-poc &&
  ansible-galaxy collection install -r requirements.yml &&
  ansible-playbook playbook.yml --check --diff
"
```

### Phase 2: Full Linux Test (Docker Interactive)
```bash
# Full interactive test (5-10 minutes)
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash

# Inside:
apt update && apt install -y ansible git sudo
cd /workspace/ansible-poc
ansible-galaxy collection install -r requirements.yml
./TEST.sh  # Use interactive script
```

### Phase 3: macOS Full Test (Parallels)
```bash
# In Parallels macOS VM:
# 1. Take snapshot
# 2. Clone repo
# 3. Test Chezmoi POC fully
# 4. Restore snapshot
# 5. Test Ansible POC fully
# 6. Create final snapshot if good
```

---

## 📋 Quick Reference

### Docker Cheat Sheet
```bash
# Start Ubuntu container
docker run -it --rm ubuntu:22.04 bash

# With your files mounted
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash

# Run command directly
docker run -it --rm -v ~/dots:/workspace ubuntu:22.04 bash -c "ls /workspace"

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Remove stopped containers
docker container prune

# Remove unused images
docker image prune
```

### Parallels Cheat Sheet
```bash
# List VMs
prlctl list -a

# Start VM
prlctl start "VM Name"

# Stop VM
prlctl stop "VM Name"

# Take snapshot
prlctl snapshot "VM Name" --name "Snapshot Name"

# Restore snapshot
prlctl snapshot-list "VM Name"  # Get snapshot ID
prlctl snapshot-switch "VM Name" -i {snapshot-id}

# Clone VM
prlctl clone "Source VM" --name "New VM" --linked
```

---

## 💡 Pro Tips

### For Parallels

**1. Use Linked Clones**
- Saves massive disk space
- Create base VM, then clone for each test
- Faster than full clones

**2. Snapshot Often**
- Before major changes
- After successful configurations
- Label clearly with timestamps

**3. Shared Folders**
- Easier than SCP/git clone
- Instant file sync
- Edit on Mac, test in VM

### For Docker

**1. Create Dockerfile for Repeatable Tests**
```dockerfile
# ~/dots/Dockerfile.test
FROM ubuntu:22.04

RUN apt update && apt install -y \
    ansible \
    git \
    curl \
    sudo

WORKDIR /workspace

CMD ["bash"]
```

**Build and use:**
```bash
docker build -t dotfiles-test -f Dockerfile.test .
docker run -it --rm -v ~/dots:/workspace dotfiles-test
```

**2. Use Docker Tags**
```bash
# Always specify version
docker run -it --rm ubuntu:22.04 bash  # Good
docker run -it --rm ubuntu bash        # Bad (uses 'latest', unpredictable)
```

**3. Save Successful Containers**
```bash
# If you configured something useful in a container
docker commit CONTAINER_ID dotfiles-configured

# Run it again later
docker run -it --rm dotfiles-configured bash
```

---

## 🎯 Next Steps

1. **Choose Your Platform**
   - Parallels for full macOS testing
   - Docker for quick Linux validation

2. **Test the POCs**
   - Start with Docker (fastest)
   - Move to Parallels for complete testing
   - Document any issues you find

3. **Iterate**
   - Make changes
   - Test again
   - Refine until perfect

4. **Deploy for Real**
   - When confident, apply to your actual Mac
   - You'll know exactly what to expect!
