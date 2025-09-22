function git-branch-search() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  local branches
  branches=$(
    git branch --all --color=never \
      | sed 's/^..//' \
      | sed 's#remotes/##' \
      | sort -u \
      | fzf -i --no-sort --tac --preview 'git log --oneline -n 20 --color=always {}'
  )

  if [ -n "$branches" ]; then
    # If it’s a remote branch, convert to local-friendly checkout
    if [[ "$branches" == origin/* ]]; then
      local local_branch="${branches#origin/}"
      BUFFER="git checkout -b $local_branch --track origin/$local_branch"
    else
      BUFFER="git checkout $branches"
    fi

    zle accept-line
  fi
}
zle -N git-branch-search

bindkey "^b" git-branch-search
