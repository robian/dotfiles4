#!/bin/sh
set -eu

source_dir="$(chezmoi source-path)"
fetch_url="$(git -C "$source_dir" remote get-url origin)"

case "$fetch_url" in
  https://github.com/*/*.git)
    repo_path="${fetch_url#https://github.com/}"
    push_url="git@github.com:${repo_path}"
    ;;
  https://github.com/*/*)
    repo_path="${fetch_url#https://github.com/}"
    push_url="git@github.com:${repo_path}.git"
    ;;
  git@github.com:*)
    push_url="$fetch_url"
    ;;
  *)
    echo "dotfiles: leaving chezmoi origin push URL unchanged for $fetch_url."
    exit 0
    ;;
esac

git -C "$source_dir" remote set-url --push origin "$push_url"
