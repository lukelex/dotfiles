function git-branch-search() {
  # Ensure we're inside a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  # Build branch list first (local prioritized, then remotes)
  # Local branches first (sorted by last commit date) then
  # remote branches (without "remotes/" prefix)
  local branch_list
  branch_list=$(
    {
      git for-each-ref --sort=-committerdate refs/heads \
        --format='%(refname:short) [local]'
      git for-each-ref --sort=-committerdate refs/remotes \
        --format='%(refname:short) [remote]' \
        | sed 's#^origin/##; s#^remotes/##'
    } | awk '!seen[$1]++'
  )

  # Run fzf on prepared list
  local selection
  selection=$(echo "$branch_list" \
    | fzf -i --tac --with-nth=1 --preview 'git log --oneline -n 20 --color=always {1}') || return 0

  # Bail if nothing selected
  [[ -z "$selection" ]] && return 0

  local branch_name=$(echo "$selection" | awk '{print $1}')
  local branch_type=$(echo "$selection" | awk '{print $2}')

  if [[ "$branch_type" == "[remote]" ]]; then
    BUFFER="git checkout -b $branch_name --track origin/$branch_name"
  else
    BUFFER="git checkout $branch_name"
  fi

  zle accept-line
}
zle -N git-branch-search

bindkey "^b" git-branch-search
