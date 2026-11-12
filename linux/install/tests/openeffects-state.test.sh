#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

config_home="$temporary/config"
mkdir -p "$config_home/openeffects"
fixture="$temporary/repo"
mkdir -p "$fixture/linux/install" "$fixture/linux/config/openeffects"
cp "$repo_root/linux/install/openeffects-state" "$fixture/linux/install/"
git -C "$fixture" init -q
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config user.name Test
printf 'old tracked state\n' > "$fixture/linux/config/openeffects/state.toml"
cp "$fixture/linux/config/openeffects/state.toml" "$temporary/expected.toml"
git -C "$fixture" add .
git -C "$fixture" commit -qm initial
git -C "$fixture" rm -q linux/config/openeffects/state.toml
git -C "$fixture" commit -qm remove
state_file="$config_home/openeffects/state.toml"
ln -s "$fixture/linux/config/openeffects/state.toml" "$state_file"

XDG_CONFIG_HOME="$config_home" bash "$fixture/linux/install/openeffects-state" --dry-run
[ -L "$state_file" ]
XDG_CONFIG_HOME="$config_home" bash "$fixture/linux/install/openeffects-state"
[ ! -L "$state_file" ]
cmp "$temporary/expected.toml" "$state_file"

printf 'local-only state\n' > "$state_file"
XDG_CONFIG_HOME="$config_home" bash "$fixture/linux/install/openeffects-state"
grep -q '^local-only state$' "$state_file"

printf 'OpenEffects local-state migration: ok\n'
