# Managed by chezmoi.

autoload -Uz colors && colors

setopt prompt_subst

function devshell_prompt_identity() {
  local identity_color="$fg_bold[green]"

  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    identity_color="$fg_bold[red]"
  fi

  print -r -- "%{${identity_color}%}%n@%m%{$reset_color%} "
}

PROMPT='$(devshell_prompt_identity)%{$fg[cyan]%}%~%{$reset_color%} '
PROMPT+='$(git_prompt_info)'
PROMPT+=$'\n%(?:%{$fg_bold[green]%}➜%{$reset_color%} :%{$fg_bold[red]%}➜%{$reset_color%} )'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})%{$reset_color%}"
