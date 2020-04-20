rm -rf ~/.config/rofi/config.rasi ~/.Xmodmap
rm -rf ~/.i3/config ~/.profile ~/.Xresources

pamac install zsh zsh-completions rofi rofi-bluetooth
pamac install autorandr xclip polybar
pamac install sysstat xdotool gconf cmake jq
pamac install flameshot vlc timeshift
pamac install etcher feh playerctl godot aseprite
pamac install nvm neovim-qt ctags diff-so-fancy
pamac install rubygems the_silver_searcher zeal
pamac install nordvpn-bin google-chrome
pamac install postgresql-10 redis docker docker-compose
pamac install slack-desktop whatsapp-nativefier telegram-desktop
pamac install dropbox woeusb spotify via-bin stress
pamac install avr-gcc dfu-programmer avrdude gcc-arm-none-eabi-bin
pamac install imagemagick-full neofetch betterlockscreen
pamac install ttf-hack nerd-fonts-complete noto-fonts-cjk

mkdir -p ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

mkdir -p ~/.config/rofi
ln -fvs ~/dotfiles/linux/rofi.rasi ~/.config/rofi/config.rasi

mkdir -p ~/.config/nvim
ln -fvs ~/dotfiles/linux/neo.vim ~/.config/nvim/init.vim

ln -fvs ~/dotfiles/linux/Xresources ~/.Xresources
ln -fvs ~/dotfiles/linux/profile ~/.profile
ln -fvs ~/dotfiles/linux/xprofile ~/.xprofile
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/peripherals/$(hostname).conf /etc/X11/xorg.conf
sudo ln -fvs ~/dotfiles/scripts/exit /usr/bin/i3exit

betterscreenlock -u ~/dotfiles/wallpapers/zelda-horse-walk.jpg
