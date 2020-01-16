rm -rf ~/.config/rofi/config.rasi ~/.Xmodmap
rm -rf ~/.i3/config ~/.profile ~/.Xresources

pamac install rofi autorandr xclip
pamac install sysstat xdotool gconf cmake
pamac install redis docker docker-compose ttf-hack jq
pamac install neovim-qt ctags zsh zsh-completions diff-so-fancy
pamac install rubygems the_silver_searcher zeal
pamac install firefox etcher viewnior telegram-desktop playerctl
pamac install flameshot variety vlc redshift timeshift
pamac install nordvpn-bin imagemagick-full google-chrome
pamac install slack-desktop whatsapp-nativefier
pamac install otf-font-awesome-5-free postgresql-10
pamac install nvm dropbox woeusb spotify debtap
pamac install avr-gcc dfu-programmer avrdude gcc-arm-none-eabi-bin

if [[ `hostname` -eq "deskjaro" ]]; then
  ln -fvs ~/dotfiles/linux/deskjaro/nvidia.conf /etc/X11/mhwd.d/nvidia.conf
fi
sudo mhwd-gpu --setmod nvidia --setxorg /etc/X11/mhwd.d/nvidia.conf

mkdir -p ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

mkdir -p ~/.config/rofi
ln -fvs ~/dotfiles/linux/rofi.rasi ~/.config/rofi/config.rasi

mkdir -p ~/.config/nvim
ln -fvs ~/dotfiles/linux/neo.vim ~/.config/nvim/init.vim

mkdir -p ~/.config/polybar
ln -fvs ~/dotfiles/linux/polybar/config ~/.config/polybar/config

ln -fvs ~/dotfiles/linux/Xresources ~/.Xresources
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile
