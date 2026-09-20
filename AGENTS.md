# AGENTS.md

Arch Linux dotfiles for a Hyprland + i3 desktop. This is a personal config repo; most changes are to the nvim config and desktop configs.

## How configs are applied (important)

- Configs are NOT used in-place. Config links declared in `linux/packages.yaml` are reconciled by dotpkg through `linux/install/sync` (`--resources`), creating **symlinks** such as `linux/config/nvim` → `~/.config/nvim`, `linux/config/hypr` → `~/.config/hypr`, `linux/config/i3/main.conf` → `~/.config/i3/config`.
- For symlinked dirs (nvim, hypr, kitty, rofi), editing the repo file takes effect immediately — no rebuild/copy step.
- `sync` preserves conflicting targets unless `--replace` is passed; dotpkg then replaces the existing path with the repo link.

## Install flow

- Entrypoint: `./linux/install/sync` (also reached through `./linux/install/all`) reconciles the selected manifest profile. Use committed `linux/hosts/<name>.yaml` overlays with `--host <name>` for machine-specific selections.
- `linux/variables.env` sets `DOTFILES="$HOME/dotfiles"`, `XDG_CONFIG_HOME`, `DOT_CONFIG="$DOTFILES/linux/config"`. Install scripts hardcode `"$HOME/dotfiles"` and assume the repo is cloned there.
- `dependencies` installs via `yay` (AUR) and is interactive (prompts).
- `linux/install/binaries` symlinks every executable in `linux/scripts/` to `/usr/local/bin/u_<script>` (hence the `u_` prefix used across configs, e.g. `u_audio`, `u_screenshot`). Commands in configs refer to these `u_*` names, not the raw scripts. Exception: Quickshell keeps its helpers inside `linux/config/quickshell/scripts/` and invokes them by absolute path, so it needs no `u_*` links; `binaries` prunes any dangling `u_*` links it no longer owns.

## Directory layout

- `linux/config/` — per-app configs (the actual content being symlinked).
- `linux/scripts/` — shell helper scripts; installed as `u_*` (except those owned by Quickshell — see `linux/config/quickshell/scripts/`).
- `linux/install/` — provisioning scripts (idempotent-ish, system-affecting).
- `linux/config/nvim/` — Neovim config, managed by lazy.nvim (plugins auto-install in `lua/plugins/`). `init.lua` sets `mapleader`/`maplocalleader` then requires `core.*`; plugins are lazy-loaded from `lua/plugins/*.lua`.
- `linux/config/oprefs/` — shared secrets across machines via the existing 1Password account. `secrets.env` (plus optional `secrets.<host>.env`) holds only `op://` secret references, never plaintext (CI guards this). `op-run-args.sh` is the single backend switch (secret references now; 1Password Environments beta later). Loaded into every interactive shell by `linux/config/zsh/secrets.zsh`; one-off use via `u_op-run` (`linux/scripts/op-run`). Runs through `op run`, so `op` must be signed in/unlocked (the desktop app autostarts and unlocks at login; headless machines need a service account token).
- `keyboards/<board>/keymap.c` — QMK keymaps, one directory per keyboard; compiled out-of-repo (`.hex` artifacts committed alongside).

## Conventions

- Commit messages use an area prefix: `[nvim]`, `[eww/linux]`, `zsh:`, `vim:`. Match the current style (bracketed `[area]` lowercase description; `zsh:`/`vim:` variants also seen). Group changes by area into separate commits.
- `.editorconfig`: 2-space indent, LF, utf-8, final newline.
- `.gitignore` ignores `linux/bin/*` and `linux/config/nvim/plugin/` (legacy vim paths, likely stale).
- Git submodules: `fonts` (lukelex/FontAwesome) and `linux/i3/polybar/polybar-scripts`.

## Validation

- `Dockerfile` is a minimal Debian image with `shellcheck` only — the intended local validation path for shell scripts (`linux/scripts`, `linux/install`).
- `.github/workflows/ci.yml` runs on push/PR to `master`: the Quickshell Node test suite (`node --test .../tests/*.test.cjs`), shellcheck over the shell scripts, and whitespace/conflict-marker checks. For nvim changes there is no CI; verify by reloading nvim (`nvim -u linux/config/nvim/init.lua` loads the repo config directly).
