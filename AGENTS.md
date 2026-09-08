# AGENTS.md

Arch Linux dotfiles for a Hyprland + i3 desktop. This is a personal config repo; most changes are to the nvim config and desktop configs.

## How configs are applied (important)

- Configs are NOT used in-place. `linux/install/configs` (run via `linux/install/all`) creates **symlinks**, e.g. `linux/config/nvim` → `~/.config/nvim`, `linux/config/hypr` → `~/.config/hypr`, `linux/config/i3/main.conf` → `~/.config/i3/config`.
- For symlinked dirs (nvim, hypr, kitty, rofi, waybar), editing the repo file takes effect immediately — no rebuild/copy step.
- `linux/install/configs` uses `rm -rf` + `ln` for several dirs (hypr, rofi, kitty, nvim). Don't run it casually; it replaces existing symlinks.

## Install flow

- Entrypoint: `./linux/install/all` which sources, in order: `dependencies`, `binaries`, `icons`, `configs`, `git-config`, `services`.
- `linux/variables.env` sets `DOTFILES="$HOME/dotfiles"`, `XDG_CONFIG_HOME`, `DOT_CONFIG="$DOTFILES/linux/config"`. Install scripts hardcode `"$HOME/dotfiles"` and assume the repo is cloned there.
- `dependencies` installs via `yay` (AUR) and is interactive (prompts).
- `linux/install/binaries` symlinks every executable in `linux/scripts/` to `/usr/local/bin/u_<script>` (hence the `u_` prefix used across configs, e.g. `u_audio`, `u_screenshot`). Commands in configs refer to these `u_*` names, not the raw scripts.

## Directory layout

- `linux/config/` — per-app configs (the actual content being symlinked).
- `linux/scripts/` — shell helper scripts; installed as `u_*`.
- `linux/install/` — provisioning scripts (idempotent-ish, system-affecting).
- `linux/config/nvim/` — Neovim config, managed by lazy.nvim (plugins auto-install in `lua/plugins/`). `init.lua` sets `mapleader`/`maplocalleader` then requires `core.*`; plugins are lazy-loaded from `lua/plugins/*.lua`.
- `keyboards/<board>/keymap.c` — QMK keymaps, one directory per keyboard; compiled out-of-repo (`.hex` artifacts committed alongside).

## Conventions

- Commit messages use an area prefix: `[nvim]`, `[eww/linux]`, `zsh:`, `vim:`. Match the current style (bracketed `[area]` lowercase description; `zsh:`/`vim:` variants also seen). Group changes by area into separate commits.
- `.editorconfig`: 2-space indent, LF, utf-8, final newline.
- `.gitignore` ignores `linux/bin/*` and `linux/config/nvim/plugin/` (legacy vim paths, likely stale).
- Git submodules: `fonts` (lukelex/FontAwesome) and `linux/i3/polybar/polybar-scripts`.

## Validation

- `Dockerfile` is a minimal Debian image with `shellcheck` only — the intended validation path for shell scripts (`linux/scripts`, `linux/install`).
- There is no automated test/lint/typecheck suite beyond that. For nvim changes there is no CI; verify by reloading nvim (`nvim -u linux/config/nvim/init.lua` loads the repo config directly).
