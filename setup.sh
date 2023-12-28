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
backup_config_file() {
    if [ -f "$1" ] && [ ! -L "$1" ]; then
        FILE="$1.old_$(date +%F_%R)"
        mv "$1" $FILE
        echo "Backup config file: $1 -> $FILE"
    fi
}

backup_config_file "$HOME/.zshrc"
backup_config_file "$HOME/.vimrc"
backup_config_file "$HOME/.config/nvim/init.vim"
backup_config_file "$HOME/.tmux.conf"
backup_config_file "$HOME/.config/zsh/hosts"

# Link config files from working directory to destination
ln -sv "$(pwd)/zsh/zshrc" "$HOME/.zshrc"
ln -sv "$(pwd)/vim/vimrc" "$HOME/.vimrc"
[ -d "$HOME/.config/nvim" ] || mkdir -p "$HOME/.config/nvim"
ln -sv "$(pwd)/nvim/init.vim" "$HOME/.config/nvim/init.vim"
ln -sv "$(pwd)/tmux/tmux.conf" "$HOME/.tmux.conf"
[ -f "$(pwd)/zsh/hosts" ] && ln -sv "$(pwd)/zsh/hosts" "$HOME/.config/zsh/hosts"

#source ~/.zshrc

exit 0
