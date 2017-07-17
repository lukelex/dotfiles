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

git config --global color.ui true
git config --global color.diff-highlight.oldNormal "red bold"
git config --global color.diff-highlight.oldHighlight "red bold 52"
git config --global color.diff-highlight.newNormal "green bold"
git config --global color.diff-highlight.newHighlight "green bold 22"

git config --global color.diff.meta "227"
git config --global color.diff.frag "magenta bold"
git config --global color.diff.commit "227 bold"
git config --global color.diff.old "red bold"
git config --global color.diff.new "green bold"
git config --global color.diff.whitespace "red reverse"

git config --global pager.diff "diff-so-fancy | less --tabs=1,5 -RFX"
git config --global pager.show "diff-so-fancy | less --tabs=1,5 -RFX"
git config --global rebase.autosquash true

function delete_local_merged_branches() {
  git branch --merged master | grep -v master | xargs git branch -d
}

# Bundler
alias be="bundle exec"

# Rails
alias rc="rails console"
alias rs="rails server"

# Docker
alias dc="docker"
alias dcsa="docker stop $(docker ps -aq)"

alias docker_remove="remove_docker_images_nones"
function remove_docker_images_nones() {
  docker rmi -f $(docker images | grep "<none>" | awk "{print \$3}")
}

function clean_docker() {
  docker rm -v $(docker ps -q --filter status=dead --filter status=exited) &
    docker rmi $(docker images -qf "dangling=true") &
    docker volume rm $(docker volume ls -qf "dangling=true")
}
