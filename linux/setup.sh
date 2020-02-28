rm -rf ~/.config/rofi/config.rasi ~/.Xmodmap
rm -rf ~/.i3/config ~/.profile ~/.Xresources

pamac install zsh zsh-completions rofi
pamac install autorandr xclip ttf-hack
pamac install sysstat xdotool gconf cmake jq
pamac install flameshot variety vlc redshift timeshift
pamac install etcher viewnior feh playerctl
pamac install nvm neovim-qt ctags diff-so-fancy
pamac install rubygems the_silver_searcher zeal
pamac install nordvpn-bin firefox
pamac install postgresql-10 redis docker docker-compose
pamac install slack-desktop whatsapp-nativefier telegram-desktop
pamac install dropbox woeusb spotify debtap
pamac install avr-gcc dfu-programmer avrdude gcc-arm-none-eabi-bin
pamac install otf-font-awesome-5-free imagemagick-full

if [[ `hostname` -eq "deskjaro" ]]; then
  ln -fvs ~/dotfiles/linux/deskjaro/nvidia.conf /etc/X11/mhwd.d/nvidia.conf
fi

mkdir -p ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

mkdir -p ~/.config/rofi
ln -fvs ~/dotfiles/linux/rofi.rasi ~/.config/rofi/config.rasi

mkdir -p ~/.config/nvim
ln -fvs ~/dotfiles/linux/neo.vim ~/.config/nvim/init.vim

ln -fvs ~/dotfiles/linux/Xresources ~/.Xresources
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile
