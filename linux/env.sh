# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export LD_LIBRARY_PATH=/usr/oracle/instantclient_11_2
export PATH=$HOME/bin:/usr/local/bin:$PATH

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# PATH="$PATH:$(ruby -e 'print Gem.user_dir')/bin"

# This is due to Arch based systems not being fond
# of mixing system gems with user gems.
rvm_ignore_gemrc_issues=1
rvm_silence_path_mismatch_check_flag=1

# Remember to enable any locales that you might need
# sudo vim /etc/locale.gen && locale-gen

source /usr/share/nvm/init-nvm.sh

# Custom executables
export PATH="/home/lukas/dotfiles/linux/bin:$PATH"

source ~/dotfiles/linux/setup/aliases
