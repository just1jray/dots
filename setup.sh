#!/bin/zsh

[[ `uname` == "Linux" ]] && OS=$(uname)
[[ `uname` == "Darwin" ]] && OS="OSX"

grep "dots/alias" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias" >> ~/.zshrc
grep "dots/function" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function" >> ~/.zshrc
grep "dots/alias_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/alias_$OS" >> ~/.zshrc
grep "dots/function_$OS" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/function_$OS" >> ~/.zshrc
grep "dots/runtime" ~/.zshrc &> /dev/null || echo "source $HOME/Developer/src/dots/runtime" >> ~/.zshrc

source ~/.zshrc

exit 0