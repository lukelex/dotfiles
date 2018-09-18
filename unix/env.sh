# Preferred editor for local and remote sessions
export EDITOR='vim'

# Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# Elixir version manager
test -s "$HOME/.kiex/scripts/kiex" && source "$HOME/.kiex/scripts/kiex"

# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Add RVM to PATH for scripting
export PATH="$PATH:$HOME/.rvm/bin"

source /usr/share/nvm/init-nvm.sh
