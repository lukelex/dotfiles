#!/usr/bin/env sh

HOSTNAME=$(hostname -s)

killall -q polybar
# If all your bars have ipc enabled, you can also use
# polybar-msg cmd quit

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

if [[ "$HOSTNAME" == "deskjaro" ]]; then
  polybar deskjaro-primary -c ~/dotfiles/linux/i3/polybar/config &
  polybar deskjaro-secundary -c ~/dotfiles/linux/i3/polybar/config &
fi

echo "Polybar launched..."
