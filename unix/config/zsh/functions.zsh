#!/usr/bin/zsh

function fancy-history() {
  local selection=$(history -t'%F %T' 0 | tac | fzf | cut -f 8- -d ' ')

  zle kill-whole-line
  zle -U "$selection"
  zle accept-line
}
zle -N fancy-history

bindkey "^r" fancy-history
