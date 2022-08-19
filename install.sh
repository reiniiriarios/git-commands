#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# windows
if [ -n "$WINDIR" ]; then
  if ! ls -al "$HOME" | grep .git-commands.sh | grep -q ^l; then
    printf "\e[32mlinking file\e[0m\n"
    HOME_WIN=$( echo $HOME | sed -E 's#^/(.{1})#\1:#' | sed 's#/#\\#g' )
    SCRIPT_DIR_WIN=$( echo $SCRIPT_DIR | sed -E 's#^/(.{1})#\1:#' | sed 's#/#\\#g' )
    cmd <<< 'mklink "'$HOME_WIN'\\.git-commands.sh" "'$SCRIPT_DIR_WIN'\\git-commands.sh"' >/dev/null
  else
    printf "\e[36msymlink already exists\e[0m\n"
    printf "  $HOME/.git-commands.sh\n"
  fi
# otherwise
elif ! [ -h "$HOME/.git-commands.sh" ]; then
  printf "\e[32mlinking file\e[0m\n"
  ln -sf "$SCRIPT_DIR/git-commands.sh" "$HOME/.git-commands.sh"
else
  printf "\e[36msymlink already exists\e[0m\n"
  printf "  $HOME/.git-commands.sh\n"
fi

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
  printf "$rclinecomment\n"
  printf "$rcline\n"
fi
