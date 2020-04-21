# Preferred editor for local and remote sessions
export EDITOR='vim'

# Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# Elixir version manager
test -s "$HOME/.kiex/scripts/kiex" && source "$HOME/.kiex/scripts/kiex"

# This loads nvm
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"

# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Setup Go's module installation path
export GOPATH=/Users/$USER/go
export PATH=$GOPATH/bin:$PATH

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

. ~/dotfiles/unix/setup/aliases
