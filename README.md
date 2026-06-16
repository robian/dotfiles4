# dotfiles4

Chezmoi source repo for shared home directory configuration.

Initial setup:

```sh
chezmoi init --apply git@github.com:robian/dotfiles4.git
```

Update an existing machine:

```sh
chezmoi update --apply
```

After applying, reload zsh:

```sh
exec zsh
```

Chezmoi scripts install mise, run `mise install`, enable Corepack/pnpm, and
install the Codex CLI after the mise config has been written. `~/.zshenv`
keeps `~/.local/bin` and mise shims on `PATH` for non-interactive SSH commands.
