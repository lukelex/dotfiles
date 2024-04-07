#!/usr/bin/zsh

setopt PROMPT_SUBST

ICON=λ
INPUT_ICON=»
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors '=*=32'

autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '%F{#DA4939}*%f'
zstyle ':vcs_info:*' stagedstr '%F{#A5C261}^%f'
zstyle ':vcs_info:git:*' formats '%F{#6D9CBE}[ %24>..>%b%<<%u%c%F{#6D9CBE}]%f'

PROMPT="%F{#6D9CBE}$ICON%f %20>...>%B%F{#AF5F00}%1~%<<%f%b %F{#6D9CBE}$INPUT_ICON%f "
RPROMPT='${vcs_info_msg_0_}%F{#519F50}%(1j.[j:%j].)%f'
