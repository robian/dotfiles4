#!/bin/sh
set -eu

zshrc="$HOME/.zshrc"

if [ ! -f "$zshrc" ]; then
  exit 0
fi

if [ ! -s "$zshrc" ]; then
  rm "$zshrc"
  exit 0
fi
