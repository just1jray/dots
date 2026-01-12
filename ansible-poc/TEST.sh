#!/bin/bash
# Ansible POC Test Script
# Interactive helper for testing Ansible dotfiles setup

set -euo pipefail

POC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$POC_DIR"

echo "🧪 Ansible Dotfiles POC Test Script"
echo "==================================="
echo ""
echo "POC Directory: $POC_DIR"
echo ""

# Check if ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed"
    echo ""
    echo "Install it with:"
    echo "  macOS:  brew install ansible"
    echo "  Linux:  sudo apt install ansible"
    echo ""
    exit 1
fi

echo "✅ Ansible is installed: $(ansible --version | head -1)"
echo ""

# Check if community.general collection is installed
if ! ansible-galaxy collection list 2>/dev/null | grep -q "community.general"; then
    echo "⚠️  community.general collection not installed"
    echo ""
    echo "Install it with:"
    echo "  ansible-galaxy collection install -r requirements.yml"
    echo ""
    read -p "Install now? (y/n): " install_collection
    if [[ "$install_collection" == "y" ]]; then
        ansible-galaxy collection install -r requirements.yml
        echo ""
    fi
fi

# Show detected system info
echo "📊 Detected System Information:"
echo "================================"
ansible localhost -m setup -a "filter=ansible_os_family,ansible_distribution,ansible_hostname,ansible_architecture" 2>/dev/null | grep -A 10 "ansible_os_family" || echo "Could not gather facts"
echo ""

# Menu
echo "What would you like to do?"
echo ""
echo "  1) Check syntax (validate playbook)"
echo "  2) List all tasks"
echo "  3) List all tags"
echo "  4) Dry run - preview ALL changes (--check --diff)"
echo "  5) Dry run - preview specific role changes"
echo "  6) Show variables that will be used"
echo "  7) Run playbook for real (CAUTION: modifies files)"
echo "  8) Run specific role only"
echo "  9) Exit"
echo ""

read -p "Enter choice [1-9]: " choice

case $choice in
    1)
        echo ""
        echo "🔍 Checking playbook syntax..."
        ansible-playbook playbook.yml --syntax-check
        echo ""
        echo "✅ Syntax is valid!"
        ;;

    2)
        echo ""
        echo "📋 All tasks in playbook:"
        echo "========================="
        ansible-playbook playbook.yml --list-tasks
        ;;

    3)
        echo ""
        echo "🏷️  All available tags:"
        echo "======================"
        ansible-playbook playbook.yml --list-tags
        ;;

    4)
        echo ""
        echo "🔍 Dry run - showing what would change..."
        echo ""
        read -p "Continue? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            ansible-playbook playbook.yml --check --diff
        else
            echo "Cancelled."
        fi
        ;;

    5)
        echo ""
        echo "Available roles:"
        echo "  - homebrew (packages)"
        echo "  - zsh (shell config)"
        echo "  - git (version control)"
        echo "  - tmux (terminal multiplexer)"
        echo "  - neovim (editor)"
        echo "  - macos (system settings)"
        echo ""
        read -p "Enter role name (or tag): " role
        echo ""
        echo "🔍 Dry run for $role..."
        ansible-playbook playbook.yml --tags "$role" --check --diff
        ;;

    6)
        echo ""
        echo "📊 Variables that will be used:"
        echo "==============================="
        ansible localhost -m debug -a "var=hostvars[inventory_hostname]" -i inventory.yml 2>/dev/null || \
        echo "Run 'ansible-playbook playbook.yml' with -v to see all variables"
        echo ""
        echo "To see specific variable:"
        echo "  ansible localhost -m debug -a 'var=git_user_name' -e '@group_vars/all.yml'"
        ;;

    7)
        echo ""
        echo "⚠️  WARNING: This will modify files in your home directory!"
        echo ""
        echo "Changes that will be made:"
        echo "  - Install Homebrew packages (if macOS)"
        echo "  - Deploy dotfiles (zshrc, gitconfig, tmux.conf, etc.)"
        echo "  - Install plugin managers (Zinit, TPM)"
        echo "  - Configure macOS settings (if macOS)"
        echo ""
        read -p "Are you sure? Type 'yes' to continue: " confirm
        if [[ "$confirm" == "yes" ]]; then
            echo ""
            echo "🚀 Running playbook..."
            echo ""
            ansible-playbook playbook.yml -v
            echo ""
            echo "✅ Complete! Check output above for any errors."
        else
            echo "Cancelled."
        fi
        ;;

    8)
        echo ""
        echo "Available tags:"
        echo "  - homebrew"
        echo "  - zsh"
        echo "  - git"
        echo "  - tmux"
        echo "  - neovim"
        echo "  - macos"
        echo ""
        read -p "Enter tag: " tag
        echo ""
        read -p "Run for real (not dry run)? (y/n): " run_real

        if [[ "$run_real" == "y" ]]; then
            echo "🚀 Running $tag role..."
            ansible-playbook playbook.yml --tags "$tag" -v
        else
            echo "🔍 Dry run for $tag..."
            ansible-playbook playbook.yml --tags "$tag" --check --diff
        fi
        ;;

    9)
        echo "Goodbye!"
        exit 0
        ;;

    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "📚 Helpful commands:"
echo "  ansible-playbook playbook.yml --check --diff       # Dry run"
echo "  ansible-playbook playbook.yml                      # Apply all"
echo "  ansible-playbook playbook.yml --tags zsh           # Just zsh"
echo "  ansible-playbook playbook.yml -v                   # Verbose"
echo "  ansible-playbook playbook.yml --list-tasks         # Show tasks"
echo "  ansible-playbook playbook.yml --syntax-check       # Validate"
echo ""
echo "📖 Read README.md and QUICKSTART.md for more info!"
echo ""
