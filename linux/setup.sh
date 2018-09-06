rm ~/.vimrc ~/.zshrc
ln -s ../rcs/vimrc ~/vimrc
ln -s ../rcs/zshrc ~/zshrc
ln -s ../linux/keys.map ~/.Xmodmap

# Set refresh rate down to 60hz to save battery
xrandr -s 1920x1080 -r 60~
