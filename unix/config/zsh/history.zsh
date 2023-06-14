#!/usr/bin/zsh

HISTFILE=$HOME/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_ALL_DUPS   # Delete old recorded entry if new entry is a duplicate.
setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space.
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks before recording entry.
setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries in the history file.
setopt SHARE_HISTORY          # Share history between all sessions.

bindkey "^[[A" history-search-backward # up
bindkey "^[[B" history-search-forward  # down

function fancy-history() {
  local selection=$(
    history -t'%F' 0 \
      | tac \
      | fzf \
      | tr --squeeze-repeats '[:blank:]' ' ' \
      | cut --fields 4- --delimiter ' '
    )

  zle kill-whole-line
  zle -U "$selection"
  zle accept-line
}
zle -N fancy-history

bindkey "^r" fancy-history
