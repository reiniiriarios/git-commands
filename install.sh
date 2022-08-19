#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

printf "\e[32mlinking file\e[0m\n"
ln -sfn "$SCRIPT_DIR/git-commands.sh" "$HOME/.git-commands.sh"

rcfile=
if [ -f "$HOME/.bashrc" ]; then
  rcfile=".bashrc"
elif [ -f "$HOME/.zshrc" ]; then
  rcfile=".zshrc"
fi

rclinecomment="# git commands"
rcline='[ -s "$HOME/.git-commands.sh" ] && . "$HOME/.git-commands.sh"'

if [ ! -z "$rcfile" ]; then
  if grep -Fq "$rcline" "$HOME/$rcfile"; then
    printf "\e[36mscript already installed in $rcfile\e[0m\n"
  else
    echo "\n$rclinecomment\n$rcline\n" >> "$HOME/$rcfile"
    printf "\e[32mscript installed in $rcfile\e[0m\n"
    . "$HOME/$rcfile"
  fi
else
  printf "\e[31munable to locate .*rc file to install script\n"
  printf "add the following lines to your shell rc file:\e[0m\n"
  printf "$rclinecomment"
  printf "$rcline"
fi

unset SCRIPT_DIR
unset rcfile
unset rclinecomment
unset rcline
