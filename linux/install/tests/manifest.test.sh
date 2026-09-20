#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

assert_equal() {
  [ "$1" = "$2" ] || { printf 'Expected %s, got %s\n' "$2" "$1" >&2; exit 1; }
}

source "$repo_root/linux/install/common.sh" --desktop
assert_equal "$(manifest_package_origin google-chrome)" aur
assert_equal "$(manifest_package_origin git)" aur
assert_equal "$(manifest_package_origin opencode-desktop)" appimage

mapfile -t top_level < <("$repo_root/linux/install/yq" -r 'keys[]' "$repo_root/linux/packages.yaml")
assert_equal "${top_level[*]}" 'source common profiles resources'
mapfile -t desktop_level < <("$repo_root/linux/install/yq" -r '.profiles.desktop | keys[]' "$repo_root/linux/packages.yaml")
assert_equal "${desktop_level[*]}" 'packages options'
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.i3."i3-wm".configs | map(select(. == "linux/xinitrc:$HOME/.xinitrc")) | length > 0' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.dotfiles.configs | map(select(. == "linux/xinitrc:$HOME/.xinitrc")) | length == 0' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.hyprland.hyprland.configs | map(select(. == "linux/config/hypr:$XDG_CONFIG_HOME/hypr")) | length > 0' "$repo_root/linux/packages.yaml" >/dev/null

mapfile -t packages < <(
  manifest_packages '.common.packages.headless'
  manifest_packages '.profiles.desktop.packages.desktop'
  manifest_packages '.profiles.desktop.packages.hyprland'
  manifest_packages '.profiles.desktop.packages.i3'
  manifest_packages '.profiles.desktop.packages.extras'
  manifest_packages '.profiles.server.packages.headless'
  for option in ipod optional nvidia nvidia-gui; do manifest_option_packages ".profiles.desktop.options.$option"; done
)
for package in "${packages[@]}"; do
  case "$(manifest_package_origin "$package")" in repo|aur|appimage) ;; *) exit 1 ;; esac
done

if (source "$repo_root/linux/install/common.sh" --host missing-host); then
  printf 'Missing host overlay unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'manifest origins: ok\n'
