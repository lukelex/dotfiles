if ! [ -x "$(command -v brew)" ]; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

if ! [ -x "$(command -v rvm)" ]; then
  \curl -sSL https://get.rvm.io | bash
fi

if ! [ -x "$(command -v nvm)" ]; then
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.6/install.sh | bash
fi

brew install ctags postgres redis the_silver_searcher

brew install vim macvim

brew install zsh zsh-completions tree diff-so-fancy

curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh

git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

" QMK Stuff
brew tap osx-cross/avr
brew tap PX4/homebrew-px4
brew update
brew install avr-gcc@8
brew link --force avr-gcc@8
brew install dfu-programmer
brew install dfu-util
brew install gcc-arm-none-eabi
brew install avrdude
git clone --recurse-submodules https://github.com/qmk/qmk_firmware ~/projects/opensource/qmk_firmware

rm ~/.vimrc ~/.zshrc
ln -s ~/dotfiles/rcs/vimrc ~/.vimrc
ln -s ~/dotfiles/rcs/zshrc ~/.zshrc
