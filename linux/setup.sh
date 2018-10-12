rm ~/.profile ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config
ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile

if [[ $(sudo dmidecode --string chassis-type) -eq "Desktop" ]]; then
  ln -fvs ~/dotfiles/linux/i3/deskjaro-blocks ~/.i3blocks.conf
else
  ln -fvs ~/dotfiles/linux/i3/blade-blocks ~/.i3blocks.conf
fi

mkdir ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

pamac install \
  rofi sysstat xdotool \
  redis \
  gvim ctags diff-so-fancy the_silver_searcher

# Set refresh rate down to 60hz to save battery
xrandr -s 1920x1080 -r 60~
