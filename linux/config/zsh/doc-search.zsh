#!/usr/bin/zsh

function search-man() {
  local selection=$(
    man -k . \
      | fzf --tiebreak=begin \
      | tr --squeeze-repeats '[:blank:]' ' ' \
      | cut --fields 1 --delimiter ' '
  )

  if [ -n "$selection" ]; then
    zle kill-whole-line
    zle push-input
    BUFFER="man $selection"
    zle accept-line
  fi
}
zle -N search-man

bindkey "^_" search-man
