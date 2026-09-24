# Homebrew packages — install with `brew bundle` or `./setup.sh --brew`
# Curated: must-haves and daily drivers only, not one-off installs.
# Claude Code is not listed: it uses Anthropic's self-updating native installer.
# Casks are macOS-only, so they sit behind `if OS.mac?` for Linuxbrew.

# Core
brew "neovim"
brew "tmux"
brew "starship"
brew "shellcheck"
brew "gh"
brew "pyenv"
brew "mosh"
brew "fzf"
brew "zoxide"
brew "jq"
brew "git-delta"

if OS.mac?
  cask "ghostty"
  cask "tailscale-app"
  cask "docker-desktop" # ships the docker CLI
  cask "raycast"
end

# Neovim language servers and formatters
brew "lua-language-server"
brew "stylua"
brew "bash-language-server"
brew "shfmt"
brew "vscode-langservers-extracted"

# Everyday tools
brew "lazygit"
brew "eza"
brew "vivid"
brew "btop"
brew "glow"
brew "yt-dlp"
brew "ffmpeg"
brew "herdr"
brew "mole"

if OS.mac?
  cask "vlc"
end

# AI tools
brew "opencode"
brew "agent-browser"

if OS.mac?
  cask "claude"
  cask "chatgpt"
  cask "codex"
  cask "cursor"
  cask "ollama-app"
  cask "grok-bot"
end
