# GIT
alias g="git"
alias gs="git status"
alias gd="git diff --color"
alias ga="git add"
alias gal="git add ."
alias gb="git branch"
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
