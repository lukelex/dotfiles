#!/usr/bin/zsh

setopt PROMPT_SUBST

ICON=λ
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors '=*=32'

autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '%F{red}*%f'
zstyle ':vcs_info:*' stagedstr '%F{green}^%f'
zstyle ':vcs_info:git:*' formats '%F{blue}[%b%u%c%F{blue}]%f'

PROMPT="%F{blue}$ICON%f %1~ %F{blue}»%f "
RPROMPT='${vcs_info_msg_0_}'
