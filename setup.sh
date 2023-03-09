#!/bin/sh

[ -d "$HOME/.config/zsh/plugins" ] || mkdir -p "$HOME/.config/zsh/plugins"
[ -d "$HOME/Developer/src" ] || mkdir -p "$HOME/Developer/src"

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

#grep "dots/alias" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias" >> ~/.zshrc
#grep "dots/function" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function" >> ~/.zshrc
#grep "dots/alias_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias_$OS" >> ~/.zshrc
#grep "dots/function_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function_$OS" >> ~/.zshrc
#grep "dots/runtime" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/runtime" >> ~/.zshrc

#source ~/.zshrc

exit 0
