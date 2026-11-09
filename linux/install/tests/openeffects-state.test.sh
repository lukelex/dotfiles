#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

config_home="$temporary/config"
mkdir -p "$config_home/openeffects"
state_file="$config_home/openeffects/state.toml"
ln -s "$repo_root/linux/config/openeffects/state.toml" "$state_file"

XDG_CONFIG_HOME="$config_home" bash "$repo_root/linux/install/openeffects-state"
[ ! -L "$state_file" ]
git -C "$repo_root" show HEAD:linux/config/openeffects/state.toml > "$temporary/expected.toml"
cmp "$temporary/expected.toml" "$state_file"

printf 'local-only state\n' > "$state_file"
XDG_CONFIG_HOME="$config_home" bash "$repo_root/linux/install/openeffects-state"
grep -q '^local-only state$' "$state_file"

printf 'OpenEffects local-state migration: ok\n'
