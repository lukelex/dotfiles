function git-branch-search() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  local branch_list
  branch_list=$(
    {
      git for-each-ref --sort=-committerdate refs/heads \
        --format='%(refname:short) %(upstream:short)' |
        awk '$2 != "" {print "0\t[t]\t" $1}'

      git for-each-ref --sort=-committerdate refs/heads \
        --format='%(refname:short) %(upstream:short)' |
        awk '$2 == "" {print "1\t[l]\t" $1}'

      git for-each-ref --sort=-committerdate refs/remotes \
        --format='%(refname:short)' |
        sed 's#^origin/##; s#^remotes/##' |
        awk '{print "2\t[r]\t" $1}'
    } | awk -F'\t' '!seen[$3]++'
  )

  local selection
  selection=$(echo "$branch_list" |
    fzf -i \
        --delimiter='\t' \
        --with-nth=2..
  ) || return 0

  [[ -z "$selection" ]] && return 0

  local branch_type=$(echo "$selection" | awk -F'\t' '{print $2}')
  local branch_name=$(echo "$selection" | awk -F'\t' '{print $3}')

  if [[ "$branch_type" == "[remote]" ]]; then
    BUFFER="git checkout -b $branch_name --track origin/$branch_name"
  else
    BUFFER="git checkout $branch_name"
  fi

  zle accept-line
}

zle -N git-branch-search
bindkey "^b" git-branch-search
