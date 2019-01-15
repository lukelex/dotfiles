. ../unix/setup

rm -rf ~/.bash_profile ~/.bashrc ~/.config/rofi/config.rasi
rm -rf ~/.profile ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config

pamac install \
  rofi sysstat xdotool xclip gconf cmake autorandr \
  redis docker docker-compose ttf-hack jq \
  nvim-gtk ctags zsh zsh-completions diff-so-fancy \
  rubygems the_silver_searcher zeal \
  firefox etcher viewnior telegram-desktop playerctl \
  flameshot variety vlc redshift timeshift

yaourt -S --noconfirm google-chrome-stable \
  slack-desktop \
  whatsapp-web-desktop \
  otf-font-awesome-5-free \
  postgresql-9.6 \
  nvm \
  phantomjs \
  dropbox \
  woeusb \
  spotify \
  debtap

git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
curl -L get.rvm.io | bash -s stable
curl -L http://install.ohmyz.sh | sh

ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile

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
