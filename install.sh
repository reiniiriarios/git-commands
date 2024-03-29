#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# LINK FILE

# windows
if [ -n "$WINDIR" ]; then
  if ! ls -al "$HOME" | grep .git-commands.sh | grep -q ^l; then
    printf "\e[32mlinking file\e[0m\n"
    HOME_WIN=$( echo $HOME | sed -E 's#^/(.{1})#\1:#' | sed 's#/#\\#g' )
    SCRIPT_DIR_WIN=$( echo $SCRIPT_DIR | sed -E 's#^/(.{1})#\1:#' | sed 's#/#\\#g' )
    cmd <<< 'runas /user:Administrator "cmd.exe /C mklink \"'$HOME_WIN'\\.git-commands.sh\" \"'$SCRIPT_DIR_WIN'\\git-commands.sh\""' >/dev/null
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

# ADD TO .bashrc/.zshrc

rclinecomment="# git commands"
rcline='[ -s "$HOME/.git-commands.sh" ] && . "$HOME/.git-commands.sh"'

if [ -f "$HOME/.bashrc" ]; then
  rcfile=".bashrc"
elif [ -f "$HOME/.zshrc" ]; then
  rcfile=".zshrc"
else
  printf "\e[31munable to locate .*rc file to install script\n"
  printf "add the following line to your shell rc file:\e[0m\n"
  printf "$rcline\n"
fi

if grep -Fq "$rcline" "$HOME/$rcfile"; then
  printf "\e[36mscript already installed in $rcfile\e[0m\n"
else
  printf "\n$rclinecomment\n$rcline\n" >> "$HOME/$rcfile"
  printf "\e[32mscript installed in $rcfile\e[0m\n"
  . "$HOME/$rcfile"
fi

# DEPENDENCIES

# make sure gsed is installed on macos
if [[ "$(uname -s)" == "Darwin"*  && ! $(which gsed) ]]; then
  if which brew >/dev/null; then
    brew install gnu-sed
  else
    printf "\e[31brew not found, please install gnu-sed\e[0m"
  fi
fi
