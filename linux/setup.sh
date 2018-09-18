rm ~/.vimrc ~/.zshrc
ln -s ~/dotfiles/rcs/vimrc ~/.vimrc
ln -s ~/dotfiles/rcs/zshrc ~/.zshrc
ln -s ~/dotfiles/linux/keys.map ~/.Xmodmap

# Set refresh rate down to 60hz to save battery
xrandr -s 1920x1080 -r 60~
