#!/bin/bash
# Quick test script for Chezmoi POC
# This script helps you test the POC without affecting your current system

set -euo pipefail

POC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Chezmoi POC Test Script"
echo "=========================="
echo ""
echo "POC Directory: $POC_DIR"
echo ""

# Check if chezmoi is installed
if ! command -v chezmoi &> /dev/null; then
    echo "❌ Chezmoi is not installed"
    echo ""
    echo "Run the bootstrap script first:"
    echo "  ./bootstrap.sh"
    echo ""
    echo "This will install:"
    echo "  - Homebrew (macOS, if needed)"
    echo "  - chezmoi (the dotfile manager)"
    echo "  - 1Password CLI (macOS, for secrets)"
    echo ""
    exit 1
fi

echo "✅ Chezmoi is installed: $(chezmoi --version)"
echo ""

# Show what files exist in POC
echo "📁 Files in POC:"
find "$POC_DIR" -type f -not -path '*/.git/*' | sed "s|$POC_DIR/|  |" | sort
echo ""

# Menu
echo "What would you like to do?"
echo ""
echo "  1) Preview what files would be created (dry run)"
echo "  2) Show templated output for dot_zshrc.tmpl"
echo "  3) Show templated output for dot_gitconfig.tmpl"
echo "  4) Initialize Chezmoi with this POC (doesn't apply yet)"
echo "  5) Apply POC to home directory (CAUTION: modifies files)"
echo "  6) Show Chezmoi data (variables available to templates)"
echo "  7) Exit"
echo ""

read -p "Enter choice [1-7]: " choice

case $choice in
    1)
        echo ""
        echo "🔍 Previewing changes..."
        echo ""
        chezmoi init --source "$POC_DIR"
        chezmoi diff
        echo ""
        echo "💡 Tip: Files with '+' would be added, '-' would be removed"
        ;;

    2)
        echo ""
        echo "📄 Templated output for dot_zshrc.tmpl:"
        echo "========================================"
        chezmoi init --source "$POC_DIR"
        chezmoi cat ~/.zshrc
        ;;

    3)
        echo ""
        echo "📄 Templated output for dot_gitconfig.tmpl:"
        echo "============================================"
        chezmoi init --source "$POC_DIR"
        chezmoi cat ~/.gitconfig
        ;;

    4)
        echo ""
        echo "🚀 Initializing Chezmoi..."
        chezmoi init --source "$POC_DIR"
        echo ""
        echo "✅ Initialized! Chezmoi source directory:"
        chezmoi source-path
        echo ""
        echo "Next steps:"
        echo "  - Run 'chezmoi diff' to preview changes"
        echo "  - Run 'chezmoi apply -v' to apply changes"
        echo "  - Run 'chezmoi cd' to open source directory"
        ;;

    5)
        echo ""
        echo "⚠️  WARNING: This will modify files in your home directory!"
        echo ""
        read -p "Are you sure? Type 'yes' to continue: " confirm
        if [[ "$confirm" == "yes" ]]; then
            echo ""
            echo "🚀 Applying POC..."
            chezmoi init --source "$POC_DIR"
            chezmoi apply -v
            echo ""
            echo "✅ Applied! Your dotfiles are now managed by Chezmoi"
        else
            echo "Cancelled."
        fi
        ;;

    6)
        echo ""
        echo "📊 Chezmoi data (variables for templates):"
        echo "==========================================="
        chezmoi init --source "$POC_DIR"
        chezmoi data
        ;;

    7)
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
echo "  chezmoi init --source $POC_DIR  # Initialize with POC"
echo "  chezmoi diff                     # Preview changes"
echo "  chezmoi apply -v                 # Apply changes"
echo "  chezmoi cd                       # Open source directory"
echo "  chezmoi managed                  # List managed files"
echo "  chezmoi data                     # Show template variables"
echo "  chezmoi doctor                   # Check for issues"
echo ""
