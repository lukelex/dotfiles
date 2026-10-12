# Use expanded commands, not the literal alias or `fg` typed at the prompt.
autoload -Uz add-zsh-hook
zmodload zsh/parameter

_window_title_set() {
  # Render control characters visibly so filenames cannot inject terminal escapes.
  print -rn -- $'\e]2;'"${(V)1}"$'\a'
}

_window_title_precmd() {
  _window_title_set "zsh — ${PWD/#$HOME/~}"
}

_window_title_preexec() {
  emulate -L zsh
  local command="${3:-${2:-$1}}" job spec id marker
  local -a words matches
  words=(${(z)command})

  if [[ ${words[1]} == fg || ${words[1]} == %* ]]; then
    spec=${words[2]:-%+}
    [[ ${words[1]} == %* ]] && spec=${words[1]}
    spec=${spec#%}
    for id in ${(k)jobtexts}; do
      job=${jobtexts[$id]}
      marker=${${(s.:.)jobstates[$id]}[2]}
      case "$spec" in
        ''|+|%) [[ $marker == + ]] || continue ;;
        -) [[ $marker == - ]] || continue ;;
        <->) [[ $id == $spec ]] || continue ;;
        \?*) [[ $job == *${spec#\?}* ]] || continue ;;
        *) [[ $job == ${spec}* ]] || continue ;;
      esac
      matches+=("$job")
    done
    # An ambiguous or missing job won't be resumed; don't label the window `fg`.
    if (( ${#matches} != 1 )); then
      _window_title_precmd
      return
    fi
    command=$matches[1]
  fi

  _window_title_set "$command — ${PWD/#$HOME/~}"
}

add-zsh-hook precmd _window_title_precmd
add-zsh-hook preexec _window_title_preexec
