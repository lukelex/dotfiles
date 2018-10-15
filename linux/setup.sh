. ../unix/setup

rm -rf ~/.bash_profile ~/.bashrc ~/.config/rofi/config.rasi
rm -rf ~/.profile ~/.vimrc ~/.zshrc ~/.Xmodmap ~/.i3/config

pamac install \
  i3blocks rofi sysstat xdotool xclip gconf cmake autorandr \
  redis docker docker-compose ttf-hack jq \
  gvim ctags zsh diff-so-fancy the_silver_searcher zeal \
  firefox etcher viewnior telegram-desktop playerctl \
  flameshot variety

yaourt_libs=( google-chrome-stable slack-desktop whatsapp-web-desktop otf-font-awesome-5-free postgresql-9.6 dropbox woeusb spotify )
for i in "${yaourt_libs[@]}"
do
  ~/dotfiles/linux/scripts/yaourt $i
done

git clone git@github.com:vivien/i3blocks-contrib.git ~/i3blocks-contrib
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
curl -L get.rvm.io | bash -s stable
curl -L http://install.ohmyz.sh | sh

ln -fvs ~/dotfiles/rcs/vimrc ~/.vimrc
ln -fvs ~/dotfiles/rcs/zshrc ~/.zshrc
ln -fvs ~/dotfiles/linux/keys.map ~/.Xmodmap
ln -fvs ~/dotfiles/linux/profile ~/.profile

if [[ `hostname` -eq "deskjaro" ]]; then
  ln -fvs ~/dotfiles/linux/i3/deskjaro-blocks ~/.i3blocks.conf
else
  ln -fvs ~/dotfiles/linux/i3/blade-blocks ~/.i3blocks.conf
fi

mkdir -p ~/.i3
ln -fvs ~/dotfiles/linux/i3/config ~/.i3/config

mkdir -p ~/.config/rofi
ln -fvs ~/dotfiles/linux/rofi.rasi ~/.config/rofi/config.rasi
