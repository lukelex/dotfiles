# Editor
alias e="nvim-qt ."

# Bash
alias t="tree"
alias open="xdg-open"
alias o="xdg-open"

# GIT
alias g="git"
alias gs="git status"
alias gd="git diff --color"
alias ga="git add"
alias gal="git add ."
alias gb="git branch --sort committerdate"
alias gc="git checkout"
alias gcb="git checkout -b"
alias gcl="git clone --recursive"
alias gmv="git mv"
alias gcm="git commit"
alias gcmf="git commit --fixup"
alias gcam="git add . && git commit"
alias gcamf="git add . && git commit --fixup"
alias gps="git push"
alias gpl="git pull --rebase"
alias gm="git merge"
alias gr="git rebase"
alias gri="git rebase -i --autosquash"
alias grhh="git reset --hard HEAD"
alias gl="git log"
alias gls="git log --oneline --decorate"
alias grl="git reflog"
alias gbam="delete_local_merged_branches"
alias gcap="git add . && git commit --amend --no-edit && git push --force-with-lease"

function clean_branches() {
  git branch --merged master | grep -v master | xargs git branch -d
}

# Bundler
alias be="bundle exec"

# Rails
alias rc="rails console"
alias rs="rails server"

# Python
alias p="python3"

# Docker
alias dc="docker"
alias dcp="docker-compose"

function clean_docker() {
  docker rm -v $(docker ps -q --filter status=dead --filter status=exited) &
    docker rmi $(docker images -qf "dangling=true") &
    docker volume rm $(docker volume ls -qf "dangling=true")
}

# Linux
alias cls="printf '\033c'"
