. ../unix/setup

rm -rf ~/.yabairc ~/.skhdrc

if ! [ -x "$(command -v brew)" ]; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

if ! [ -x "$(command -v rvm)" ]; then
  \curl -sSL https://get.rvm.io | bash
fi

brew install ctags postgres redis the_silver_searcher \
             vim macvim zsh zsh-completions tree diff-so-fancy \
             docker docker-compose neovim jq yabai skhd

brew cask install etcher vlc nordvpn google-chrome slack \
                  nvm spotify telegram

curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh

" QMK Stuff
brew tap osx-cross/avr
brew tap PX4/homebrew-px4
brew update
brew install avr-gcc@8
brew link --force avr-gcc@8
brew install dfu-programmer dfu-util gcc-arm-none-eabi avrdude
git clone --recurse-submodules https://github.com/qmk/qmk_firmware ~/projects/opensource/qmk_firmware

ln -fvs ~/dotfiles/rcs/yabairc ~/.yabairc
ln -fvs ~/dotfiles/rcs/skhdrc ~/.skhdrc
