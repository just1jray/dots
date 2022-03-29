#!/bin/zsh

grep "dotfiles/alias" ~/.zshrc &> /dev/null || echo 'source $HOME/Developer/dotfiles/alias' >> ~/.zshrc
grep "dotfiles/function" ~/.zshrc &> /dev/null || echo 'source $HOME/Developer/dotfiles/function' >> ~/.zshrc
grep "dotfiles/alias_$OS" ~/.zshrc &> /dev/null || echo 'source $HOME/Developer/dotfiles/alias_$OS' >> ~/.zshrc
grep "dotfiles/function_$OS" ~/.zshrc &> /dev/null || echo 'source $HOME/Developer/dotfiles/function_$OS' >> ~/.zshrc
grep "dotfiles/runtime" ~/.zshrc &> /dev/null || echo 'source $HOME/Developer/dotfiles/runtime' >> ~/.zshrc

source ~/.zshrc

exit 0
