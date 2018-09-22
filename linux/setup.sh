rm ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config
ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap

mkdir ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

# Set refresh rate down to 60hz to save battery
xrandr -s 1920x1080 -r 60~
