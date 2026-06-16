# Managed by chezmoi.

setopt prompt_subst

function devshell_set_prompt() {
  local identity_color="green"

  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    identity_color="red"
  fi

  PROMPT="%B%F{${identity_color}}%n@%m%f%b %F{cyan}%~%f "
  PROMPT+='$(git_prompt_info)'
  PROMPT+=$'\n%(?.%B%F{green}➜%f%b .%B%F{red}➜%f%b )'
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd devshell_set_prompt
devshell_set_prompt

ZSH_THEME_GIT_PROMPT_PREFIX="%B%F{blue}git:(%F{red}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f%b "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{blue}) %F{yellow}✗%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{blue})%f"
