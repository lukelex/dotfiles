#!/usr/bin/env zsh
emulate -L zsh
setopt errexit
local title_source="${0:A:h:h}/window-title.zsh"
load_title_functions() {
  source "$title_source"
  add-zsh-hook -d precmd _window_title_precmd
  add-zsh-hook -d preexec _window_title_preexec
}
load_title_functions

local title
_window_title_set() { title=$1; }
assert_title() {
  if [[ $title != "$1" ]]; then
    print -ru2 -- "Expected: $1"
    print -ru2 -- "Actual:   $title"
    exit 1
  fi
}

_window_title_precmd
assert_title "zsh — ${PWD/#$HOME/~}"
_window_title_preexec e 'nvim .' 'nvim .'
assert_title "nvim . — ${PWD/#$HOME/~}"
_window_title_preexec gs 'git status' 'git status'
assert_title "git status — ${PWD/#$HOME/~}"
_window_title_preexec 'e some/file.lua' 'nvim . ' 'nvim . some/file.lua'
assert_title "nvim . some/file.lua — ${PWD/#$HOME/~}"

sleep 60 &
local first=$!
sleep 61 &
local second=$!
trap 'kill $first $second 2>/dev/null || true; wait 2>/dev/null || true' EXIT

_window_title_preexec fg fg fg
assert_title "sleep 61 — ${PWD/#$HOME/~}"
_window_title_preexec 'fg %-' 'fg %-' 'fg %-'
assert_title "sleep 60 — ${PWD/#$HOME/~}"
_window_title_preexec 'fg %1' 'fg %1' 'fg %1'
assert_title "sleep 60 — ${PWD/#$HOME/~}"
_window_title_preexec 'fg %?61' 'fg %?61' 'fg %?61'
assert_title "sleep 61 — ${PWD/#$HOME/~}"
_window_title_preexec '%sleep' '%sleep' '%sleep'
assert_title "zsh — ${PWD/#$HOME/~}"
_window_title_preexec '%2' '%2' '%2'
assert_title "sleep 61 — ${PWD/#$HOME/~}"
_window_title_preexec 'fg %99' 'fg %99' 'fg %99'
assert_title "zsh — ${PWD/#$HOME/~}"

# The OSC payload must not contain control characters from a command or path.
unfunction _window_title_set
load_title_functions
local output=$(_window_title_set $'nvim bad\e]2;injected\a\nfile')
[[ $output == $'\e]2;nvim bad^[]2;injected^G\\nfile\a' ]] || {
  print -ru2 -- "Unsafe title payload: ${(V)output}"
  exit 1
}
print -- 'Window title tests passed'
