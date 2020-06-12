#!/usr/bin/env sh

HOSTNAME=$(hostname -s)

killall -q polybar
# If all your bars have ipc enabled, you can also use
# polybar-msg cmd quit

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

polybar $HOSTNAME -c ~/dotfiles/linux/i3/polybar/bars

echo "Polybar launched..."
