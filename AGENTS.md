# AGENTS.md

Arch Linux dotfiles for a Hyprland + i3 desktop. This is a personal config repo; most changes are to the nvim config and desktop configs.

## How configs are applied (important)

- Configs are NOT used in-place. Config links declared in `linux/packages.yaml` are reconciled by dotpkg through `linux/install/sync` (`--resources`), creating **symlinks** such as `linux/config/nvim` → `~/.config/nvim`, `linux/config/hypr` → `~/.config/hypr`, `linux/config/i3/main.conf` → `~/.config/i3/config`.
- For symlinked dirs (nvim, hypr, kitty, rofi, fuzzel, quickshell), editing the repo file takes effect immediately — no rebuild/copy step.
- `sync` preserves conflicting targets unless `--replace` is passed; dotpkg then replaces the existing path with the repo link.

## Install flow

- Entrypoint: `./linux/install/sync` (also reached through `./linux/install/all`) reconciles the selected profile through dotpkg. The first run seeds `$XDG_CONFIG_HOME/dotpkg/package.yaml` from `linux/packages.yaml`; dotpkg keeps its state beside the manifest in `state.yaml`. Use committed `linux/hosts/<name>.yaml` overlays with `--host <name>` for machine-specific selections.
- `linux/variables.env` defaults `DOTFILES` to `$HOME/dotfiles` and sets `XDG_CONFIG_HOME` and `DOT_CONFIG`. The installer requires the repo at `$HOME/dotfiles` and bootstraps `yay` if needed; dotpkg then reconciles the selected packages and resources. Use `--dry-run` to preview the reconciliation (dotpkg's local manifest may still be initialized).
- On desktop syncs, `linux/install/binaries` links executable `linux/scripts/` helpers to `/usr/local/bin/u_<script>` (e.g. `u_audio`, `u_screenshot`). Most configs use those names; lock-screen helpers and some session startup commands use repo paths directly. Quickshell keeps its own helpers in `linux/config/quickshell/scripts/` and invokes them by absolute path. `binaries` prunes dangling `u_*` links it no longer owns.

## Directory layout

- `linux/config/` — per-app configs (the actual content being symlinked).
- `linux/scripts/` — shell helper scripts; installed as `u_*` (except those owned by Quickshell — see `linux/config/quickshell/scripts/`).
- `linux/install/` — provisioning scripts (idempotent-ish, system-affecting).
- `linux/config/nvim/` — Neovim config managed by lazy.nvim. `init.lua` sets `mapleader`/`maplocalleader` and loads `core.*`; `lua/plugins/*.lua` declares plugins, which lazy.nvim installs under Neovim's data directory.
- `linux/config/oprefs/` — shared 1Password secret references. `secrets.env` (plus optional `secrets.<host>.env`) holds only `op://` references, never plaintext (CI guards this). `op-run-args.sh` supplies the `op run` arguments for interactive zsh via `linux/config/zsh/secrets.zsh` and one-off commands via `u_op-run` (`linux/scripts/op-run`). Secret resolution requires access to an unlocked 1Password account or service-account authentication.
- `keyboards/<board>/keymap.c` — QMK keymaps, one directory per keyboard; compiled out-of-repo (`.hex` artifacts committed alongside).

## Conventions

- Commit messages use an area prefix: `[nvim]`, `[quickshell]`, `zsh:`, `vim:`. Match the current style (bracketed `[area]` lowercase description; `zsh:`/`vim:` variants also seen). Group changes by area into separate commits.
- `.editorconfig`: 2-space indent, LF, utf-8, final newline.
- `.gitignore` excludes the downloaded dotpkg binary, generated Lucide PNGs, and OpenCode's app-managed credential file.
- Git submodules: `fonts` (lukelex/FontAwesome).

## Validation

- Before committing any shell-script change, run `docker compose run --rm shellcheck`. The `shellcheck` service in `docker-compose.yml` builds the minimal Debian `Dockerfile` image and lints `linux/scripts`, `linux/install`, and Quickshell shell helpers with `shellcheck -S error`.
- `.github/workflows/ci.yml` runs on push/PR to `master`: Quickshell Node tests and QML lint, shellcheck, installer tests, YAML formatting, zsh syntax and 1Password reference guards, and whitespace checks. For nvim changes there is no CI; verify by reloading nvim (`nvim -u linux/config/nvim/init.lua` loads the repo config directly).
