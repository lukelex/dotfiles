#!/usr/bin/zsh

function fancy-history() {
  local selection=$(history -t'%F %T' 0 | tac | fzf | tr -s '[:blank:]' ' ' | cut -f 5- -d ' ')

  zle kill-whole-line
  zle -U "$selection"
  zle accept-line
}
zle -N fancy-history

bindkey "^r" fancy-history
