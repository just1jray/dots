#!/bin/bash
# Bootstrap script for Chezmoi POC
# Installs prerequisites needed to run chezmoi
# Run this BEFORE using TEST.sh or chezmoi commands

set -euo pipefail

echo "🚀 Chezmoi POC Bootstrap"
echo "======================="
echo ""

# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

echo "Detected: $OS ($ARCH)"
echo ""

# macOS-specific setup
if [[ "$OS" == "Darwin" ]]; then
    # Install Homebrew if missing
    if ! command -v brew &> /dev/null; then
        echo "📦 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [[ "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        else
            eval "$(/usr/local/bin/brew shellenv)"
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        fi

        echo "✅ Homebrew installed"
    else
        echo "✅ Homebrew already installed"
    fi

    # Install chezmoi
    if ! command -v chezmoi &> /dev/null; then
        echo "📦 Installing chezmoi..."
        brew install chezmoi
        echo "✅ chezmoi installed"
    else
        echo "✅ chezmoi already installed"
    fi

    # Install 1Password CLI (user preference: auto-install on macOS)
    if ! command -v op &> /dev/null; then
        echo "📦 Installing 1Password CLI..."
        brew install --cask 1password-cli
        echo "✅ 1Password CLI installed"
    else
        echo "✅ 1Password CLI already installed"
    fi

# Linux-specific setup
else
    # Ensure basic tools are available
    echo "📦 Checking for git and curl..."
    if ! command -v git &> /dev/null || ! command -v curl &> /dev/null; then
        echo "Installing git and curl..."
        sudo apt update -qq
        sudo apt install -y git curl
    fi
    echo "✅ git and curl available"

    # Install chezmoi
    if ! command -v chezmoi &> /dev/null; then
        echo "📦 Installing chezmoi..."
        sh -c "$(curl -fsLS get.chezmoi.io)"

        # Add to PATH if needed
        if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi

        echo "✅ chezmoi installed to ~/.local/bin/chezmoi"
    else
        echo "✅ chezmoi already installed"
    fi
fi

echo ""
echo "🎉 Bootstrap complete!"
echo ""
echo "Installed:"
if [[ "$OS" == "Darwin" ]]; then
    echo "  ✓ Homebrew (macOS package manager)"
    echo "  ✓ chezmoi (dotfile manager)"
    echo "  ✓ 1Password CLI (for secrets integration)"
else
    echo "  ✓ chezmoi (dotfile manager)"
    echo "  ✓ git and curl (if needed)"
fi
echo ""
echo "Next steps:"
echo "  1. Run the interactive test script:"
echo "     ./TEST.sh"
echo ""
echo "  2. Or initialize chezmoi directly:"
echo "     chezmoi init --source ."
echo "     chezmoi diff          # Preview changes"
echo "     chezmoi apply -v      # Apply changes"
echo ""
echo "  3. For 1Password integration:"
echo "     - Uncomment 1Password lines in .chezmoi.toml.tmpl"
echo "     - Sign in: op signin"
echo "     - Then run chezmoi apply"
echo ""
