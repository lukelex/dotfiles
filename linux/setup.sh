. ../unix/setup

pamac install polybar rofi autorandr xclip

pamac install \
  sysstat xdotool gconf cmake \
  redis docker docker-compose ttf-hack jq \
  neovim-qt ctags zsh zsh-completions diff-so-fancy \
  rubygems the_silver_searcher zeal \
  firefox etcher viewnior telegram-desktop playerctl \
  flameshot variety vlc redshift timeshift \
  nordvpn-bin avr-gcc dfu-programmer avrdude

yaourt -S --noconfirm google-chrome-stable \
  slack-desktop whatsapp-web-desktop \
  otf-font-awesome-5-free postgresql-9.6 \
  nvm dropbox woeusb spotify debtap \
  gcc-arm-none-eabi-bin

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
