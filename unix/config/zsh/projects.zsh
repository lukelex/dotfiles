export PROJECTS_PATH="$HOME/projects"

function projects-search() {
  local delimiter=":"
  local s=$PROJECTS_PATH$delimiter
  local directories=()

  while [[ $s ]]
  do
    local scope="${s%%"$delimiter"*}"
    for folder in $(ls $scope)
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

  zle kill-whole-line
  zle -U "cd $selection"
  zle accept-line
  zle execute-named-cmd
}
zle -N projects-search

bindkey "^p" projects-search
