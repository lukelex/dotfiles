#!/usr/bin/zsh

# history settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt EXTENDED_HISTORY
setopt HIST_SAVE_NO_DUPS

function fancy-history() {
  local selection=$(history -t'%F %T' 0 | tac | fzf | tr -s '[:blank:]' ' ' | cut -f 5- -d ' ')

  zle kill-whole-line
  zle -U "$selection"
  zle accept-line
}
zle -N fancy-history

bindkey "^r" fancy-history
