#!/bin/sh

# Check for directories or create them
[ -d "$HOME/.config/zsh/plugins" ] || mkdir -p "$HOME/.config/zsh/plugins"
[ -d "$HOME/Developer/src" ] || mkdir -p "$HOME/Developer/src"

# Install plugins
if [ ! -d "$HOME/.config/zsh/plugins/powerlevel10k" ]; then 
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.config/zsh/plugins/powerlevel10k"
    echo 'source ~/.config/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
fi

if [ ! -d "$HOME/.config/zsh/plugins/zsh-autocomplete" ]; then
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "$HOME/.config/zsh/plugins/zsh-autocomplete"
fi

if [ ! -d "$HOME/.config/zsh/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 -- https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.config/zsh/plugins/zsh-autosuggestions"
fi

if [ ! -d "$HOME/.config/zsh/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.config/zsh/plugins/zsh-syntax-highlighting"
fi

# Backup existing config files if they exist
if [ -f "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.old_$(date +%F_%R)"
    echo "Backup file: $HOME/.zshrc -> $HOME/.zshrc.old_$(date +%F_%R)"
fi

if [ -f "$HOME/.vimrc" ]; then
    mv "$HOME/.vimrc" "$HOME/.vimrc.old_$(date +%F_%R)"
    echo "Backup file: $HOME/.vimrc -> $HOME/.vimrc.old_$(date +%F_%R)"
fi

if [ -f "$HOME/.config/nvim/init.vim" ]; then
    mv "$HOME/.config/nvim/init.vim" "$HOME/.config/nvim/init.vim.old_$(date +%F_%R)"
    echo "Backup file: $HOME/.config/nvim/init.vim -> $HOME/.config/nvim/init.vim.old_$(date +%F_%R)"
fi

if [ -f "$HOME/.tmux.conf" ]; then
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.old_$(date +%F_%R)"
    echo "Backup file: $HOME/.tmux.conf -> $HOME/.tmux.conf.old_$(date +%F_%R)"
fi

if [ -f "$HOME/.config/zsh/hosts" ]; then
    mv "$HOME/.config/zsh/hosts" "$HOME/.config/zsh/hosts.old_$(date +%F_%R)"
    echo "Backup file: $HOME/.config/zsh/hosts -> $HOME/.config/zsh/hosts.old_$(date +%F_%R)"
fi

# Link config files from working directory to destination
ln -sv "$(pwd)/zsh/zshrc" "$HOME/.zshrc"

ln -sv "$(pwd)/vim/vimrc" "$HOME/.vimrc"

[ d "$HOME/.config/nvim" ] || mkdir -p "$HOME/.config/nvim"
ln -sv "$(pwd)/nvim/init.vim" "$HOME/.config/nvim/init.vim"

ln -sv "$(pwd)/tmux/tmux.conf" "$HOME/.tmux.conf"

[ -d "$HOME/.config/zsh" ] || mkdir -p "$HOME/.config/zsh"
[ -f "$(pwd)/zsh/hosts" ] && ln -sv "$(pwd)/zsh/hosts" "$HOME/.config/zsh/hosts"

#source ~/.zshrc

exit 0
