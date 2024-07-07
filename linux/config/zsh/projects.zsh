export PROJECTS_PATH="$HOME/projects"

function projects-search() {
  local delimiter=":"
  local s=$PROJECTS_PATH$delimiter
  local directories=()

  while [[ $s ]]
  do
    local scope="${s%%"$delimiter"*}"
    for folder in $(find $scope -maxdepth 1 -type d,l | tail -n +2)
    do
      directories+=( "$(basename $folder) $scope" )
    done
    s=${s#*"$delimiter"}
  done;

  local selection=$(
    printf "%s\n" "${directories[@]}" \
      | fzf -i --no-sort --nth 1 \
      | awk '{print $2"/"$1}'
  )

  if [ -n "$selection" ]; then
    zle kill-whole-line
    zle push-input
    BUFFER="cd $selection"
    zle accept-line
  fi
}
zle -N projects-search

bindkey "^p" projects-search
