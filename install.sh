#/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "\033[32mlinking file\033[0m"
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
    echo "\033[36mscript already installed in $rcfile\033[0m"
  else
    echo "\n$rclinecomment\n$rcline\n" >> "$HOME/$rcfile"
    echo "\033[32mscript installed in $rcfile\033[0m"
    . "$HOME/$rcfile"
  fi
else
  echo "\033[31munable to locate .*rc file to install script"
  echo "add the following lines to your shell rc file:\033[0m"
  echo "$rclinecomment"
  echo "$rcline"
fi

unset SCRIPT_DIR
unset rcfile
unset rclinecomment
unset rcline

