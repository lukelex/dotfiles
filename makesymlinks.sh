#!/bin/bash
############################
# .make.sh
# This script creates symlinks from the home directory to any desired dotfiles in ~/dotfiles
############################

########## Variables

dir=~/dotfiles                    # dotfiles directory
files=("bashrc" "vimrc" "vim" "zshrc")    # list of files/folders to symlink in homedir

##########

# change to the dotfiles directory
echo "Changing to $dir directory"
cd $dir
echo "...done"

echo "Deleting any existing dotfiles from ~ to $olddir"
# move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks
for file in $files; do
  rm ~/.$file 
  echo "Creating symlink to $file in home directory."
  ln -s $dir/$file ~/.$file
done
