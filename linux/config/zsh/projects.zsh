export PROJECTS_PATH="$HOME/projects"

function projects-search() {
  local delimiter=":"
  local s=$PROJECTS_PATH$delimiter
  local directories=()

  while [[ $s ]]
  do
    local scope="${s%%"$delimiter"*}"
    for folder in $(find $scope -maxdepth 1 -type d | tail -n +2)
    do
      directories+=( "$folder $scope" )
    done
    s=${s#*"$delimiter"}
  done;

  local selection=$(
    printf "%s\n" "${directories[@]}" \
      | fzf -i --height=50% --no-sort --nth 1 \
      | awk '{print $2"/"$1}'
  )

  if [ -n "$selection" ]; then
    zle kill-whole-line
    zle -U "cd $selection"
  fi

  zle accept-line
}
zle -N projects-search

bindkey "^p" projects-search
