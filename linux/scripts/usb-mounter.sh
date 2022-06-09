#!/usr/bin/env sh

set -e

drives=$(lsblk  --noheadings --raw | awk '$1~/s.*[[:digit:]]/' | awk '{print "/dev/"$1,$7}')
mounted=$(echo $drives | awk '$3!=""' | awk '{print "unmount",$1}')
unmounted=$(echo $drives | awk '$3==""' | awk '{print "mount",$1}')

selected=$(echo "$mounted $unmounted" | rofi show -dmenu -p "drives")
[[ -z $selected ]] && exit

action=$(echo $selected | awk '{print $1}')
drive=$(echo $selected | awk '{print $2}')

result=$(udisksctl $action --block-device $drive)

if [[ "$action" = "mount" ]]; then
  notify-send -a System \
              -i ~/dotfiles/fonts/fa6/svgs/light/usb-drive.svg \
              -h string:wired-tag:system \
              'Drive' 'Successfully mounted'
else
  notify-send -a System \
              -i ~/dotfiles/fonts/fa6/svgs/light/usb-drive.svg \
              -h string:wired-tag:system \
              'Drive' 'Successfully unmounted'
fi
