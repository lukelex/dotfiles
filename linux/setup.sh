. ../unix/setup

rm -rf ~/.bash_profile ~/.bashrc
rm -rf ~/.profile ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config

pamac install \
  i3blocks rofi sysstat xdotool xclip gconf \
  redis docker \
  gvim ctags zsh diff-so-fancy the_silver_searcher \
  firefox etcher viewnior \
  telegram-desktop

~/dotfiles/linux/scripts/yaourt google-chrome-stable whatsapp-web-desktop vundle otf-font-awesome-5-free postgresql-9.6 dropbox woeusb

git clone git@github.com:vivien/i3blocks-contrib.git ~/i3blocks-contrib

curl -L http://install.ohmyz.sh | sh

ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile

if [[ $(sudo dmidecode --string chassis-type) -eq "Desktop" ]]; then
  ln -fvs ~/dotfiles/linux/i3/deskjaro-blocks ~/.i3blocks.conf
else
  ln -fvs ~/dotfiles/linux/i3/blade-blocks ~/.i3blocks.conf
fi

mkdir -p ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config
