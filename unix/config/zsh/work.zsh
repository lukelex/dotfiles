export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export DEVBOX_ROOT_PATH="$HOME/projects/devbox"
alias dev="$DEVBOX_ROOT_PATH/cli"
source $DEVBOX_ROOT_PATH/bin/autocomplete

autoload -Uz compinit && compinit
autoload -U +X bashcompinit && bashcompinit
complete -W "$($DEVBOX_ROOT_PATH/cli auto)" cli
