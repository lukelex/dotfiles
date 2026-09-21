#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

assert_equal() {
  [ "$1" = "$2" ] || { printf 'Expected %s, got %s\n' "$2" "$1" >&2; exit 1; }
}

mapfile -t top_level < <("$repo_root/linux/install/yq" -r 'keys[]' "$repo_root/linux/packages.yaml")
assert_equal "${top_level[*]}" 'source common profiles resources'
mapfile -t desktop_level < <("$repo_root/linux/install/yq" -r '.profiles.desktop | keys[]' "$repo_root/linux/packages.yaml")
assert_equal "${desktop_level[*]}" 'packages options'
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.i3."i3-wm".configs | map(select(. == "linux/xinitrc:$HOME/.xinitrc")) | length > 0' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.dotfiles.configs | map(select(. == "linux/xinitrc:$HOME/.xinitrc")) | length == 0' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.hyprland.hyprland.configs | map(select(. == "linux/config/hypr:$XDG_CONFIG_HOME/hypr")) | length > 0' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.hyprland | (has("kanshi") and has("wl-clipboard") and has("xwaylandvideobridge"))' "$repo_root/linux/packages.yaml" >/dev/null
"$repo_root/linux/install/yq" -e '.profiles.desktop.packages.desktop."opencode-desktop".source == "appimage" and .profiles.desktop.packages.desktop."opencode-desktop".sha256 == "e5e59645631380f545449118c5dbb069a45d4c7a98a996e62b7ce42bfb661eb2"' "$repo_root/linux/packages.yaml" >/dev/null

printf 'manifest structure: ok\n'
