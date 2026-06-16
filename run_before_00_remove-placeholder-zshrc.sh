#!/bin/sh
set -eu

zshrc="$HOME/.zshrc"
placeholder="# Placeholder managed by devshell to suppress zsh-newuser-install."

if [ ! -f "$zshrc" ]; then
  exit 0
fi

if [ ! -s "$zshrc" ]; then
  rm "$zshrc"
  exit 0
fi

if [ "$(cat "$zshrc")" = "$placeholder" ]; then
  rm "$zshrc"
fi

