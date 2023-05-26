#!/usr/bin/zsh

autoload -Uz vcs_info
precmd() { vcs_info }

ICON=λ
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors '=*=32'

zstyle ':vcs_info:git:*' formats '[%b]'

setopt PROMPT_SUBST
PROMPT="%F{blue}$ICON%f > "
RPROMPT='%F{green}${vcs_info_msg_0_}%f'
