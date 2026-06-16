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

After applying, reload zsh and install configured mise tools:

```sh
exec zsh
mise install
```
