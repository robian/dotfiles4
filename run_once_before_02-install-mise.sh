#!/bin/sh
set -eu

if command -v mise >/dev/null 2>&1; then
  exit 0
fi

if [ -x "$HOME/.local/bin/mise" ]; then
  exit 0
fi

mkdir -p "$HOME/.local/bin"

curl https://mise.run | sh
