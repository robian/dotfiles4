#!/bin/sh
set -eu

if ! command -v mise >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$HOME/.local/share/zsh/site-functions"

mise completion zsh > "$HOME/.local/share/zsh/site-functions/_mise"

