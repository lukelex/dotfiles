rm ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config
ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap

if [[ $(sudo dmidecode --string chassis-type) -eq "Desktop" ]]; then
  ln -fvs ~/dotfiles/linux/i3/deskjaro-status ~/.i3status.conf
else
  ln -fvs ~/dotfiles/linux/i3/blade-status ~/.i3status.conf
fi

mkdir ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

pamac install \
  gvim \
  ctags \
  redis \
  diff-so-fancy \
  the_silver_searcher

# Set refresh rate down to 60hz to save battery
xrandr -s 1920x1080 -r 60~
