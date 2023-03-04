#!/bin/sh

#[[ `uname` == "Linux" ]] && OS=$(uname)
#[[ `uname` == "Darwin" ]] && OS="OSX"

[ -d "$HOME/.zsh/plugins" ] || mkdir -p "$HOME/.zsh/plugins"
[ -d "$HOME/Developer/src" ] || mkdir -p "$HOME/Developer/src"

if [ ! -d "$HOME/.zsh/plugins/powerlevel10k" ]; then 
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.zsh/plugins/powerlevel10k"
  #  echo 'source ~/.zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
fi

if [ ! -d "$HOME/.zsh/plugins/zsh-autocomplete" ]; then
  git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "$HOME/.zsh/plugins/zsh-autocomplete"
fi

if [ ! -d "$HOME/.zsh/plugins/zsh-autosuggestions" ]; then
  git clone --depth 1 -- https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.zsh/plugins/zsh-autosuggestions"
fi

if [ ! -d "$HOME/.zsh/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.zsh/plugins/zsh-syntax-highlighting"
fi

#grep "dots/alias" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias" >> ~/.zshrc
#grep "dots/function" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function" >> ~/.zshrc
#grep "dots/alias_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias_$OS" >> ~/.zshrc
#grep "dots/function_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function_$OS" >> ~/.zshrc
#grep "dots/runtime" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/runtime" >> ~/.zshrc

#source ~/.zshrc

exit 0
