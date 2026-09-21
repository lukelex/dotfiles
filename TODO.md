# Installation-flow audit

## High impact

1. **No `yay` bootstrap, but every package resolves through it**
   - `linux/packages.yaml:1` sets `source: aur`.
   - `preflight` only checks `pacman` and `sudo` (`linux/install/preflight:23-25`).
   - A fresh Arch install normally has neither `yay` nor its build prerequisites. The first `sync` therefore cannot install the package manager it depends on.
   - **Fix:** add an explicit bootstrap stage/check for `base-devel`, `git`, and `yay`, or make repository packages use pacman and bootstrap `yay` only when an AUR package is selected.

2. **Primary installer does not install the `u_*` command links**
   - `sync`/`all` run only dotpkg (`linux/install/sync:62`, `linux/install/all:33`).
   - Desktop configs invoke many commands such as `u_audio`, `u_exit`, `u_screenshot`, `u_wallpaper`, and `u_performance-profile`.
   - Those are installed solely by `linux/install/binaries`, which is not called or clearly required by the primary flow.
   - A clean install will have working symlinked configs but broken keybindings, bar controls, lock behavior, and startup helpers.
   - **Fix:** make `binaries` part of the supported desktop flow, or replace `/usr/local/bin/u_*` with user-owned managed links/resources.

3. **The installer supports arbitrary clone locations, but the desktop does not**
   - Installer derives `DOTFILES` from its own location (`common.sh:6-8`), so `~/src/dotfiles` installs correctly.
   - Yet numerous runtime configs hard-code `$HOME/dotfiles`, including `variables.env`, i3, Hyprland, Quickshell, autostart, and shell scripts.
   - The README itself uses `cd dotfiles`, which does not guarantee `$HOME/dotfiles`.
   - **Fix:** either require/clamp installation to `$HOME/dotfiles` before syncing, or remove hard-coded paths and propagate the actual repository location safely.

4. **Repository manifest updates do not reach existing installations**
   - `linux/install/dotpkg:65-68` copies `packages.yaml` only when `~/.config/dotpkg/package.yaml` does not exist.
   - Subsequent `sync` runs use the old per-user copy, so new package declarations, resource links, service definitions, changed hashes, and corrections committed to this repo are ignored.
   - **Fix:** define an update/migration model: managed baseline plus local selections, an explicit `update-manifest` command with a merge preview, or make the repository manifest authoritative while keeping selections/state separate.

## Functional package holes

5. **Hyprland startup calls packages absent from the Hyprland selection**
   - `linux/config/hypr/hyprland.lua:114-116` starts `xwaylandvideobridge` and `wl-paste`.
   - `linux/config/autostart:15` starts `kanshi`.
   - None appear in the Hyprland package group in `packages.yaml:162-181`.
   - Result: video bridge, clipboard persistence, and output-profile management fail on a clean Hyprland install.
   - **Fix:** add `xwaylandvideobridge`, `wl-clipboard`, and `kanshi` to that group.

6. **i3 startup requires `play`, but `sox` is only in the Hyprland group**
   - `linux/config/i3/main.conf:45` invokes `play`.
   - `sox` is declared only at `packages.yaml:174`.
   - **Fix:** move `sox` to shared desktop packages or add it to i3.

7. **The imperative setup scripts are effectively orphaned**
   - `post`, `configs-system`, `icons`, and `kmonad-device-manager` are not part of `all`; `all` is just a `sync` wrapper.
   - README mentions only `post` as optional, while `configs-system` and `icons` establish system paths/fonts and `binaries` is required for the checked-in desktop config to work.
   - **Fix:** categorize scripts as required and invoked by the main flow, optional with explicit features/dependencies, or retired/deleted. Then document the resulting flow.

## Reliability/documentation gaps

8. **Preflight checks too little for first install**
   - It does not verify `curl` (needed to obtain dotpkg), `sha256sum`, `yay`, network access, or that the user’s package database is initialized/current.
   - It also passes before later failures in AppImage/resource/service steps.
   - **Fix:** provide actionable checks before downloading or mutating anything, including a `--dry-run` plan that does not require bootstrap tools unless needed.

9. **Stale README describes a different desktop stack**
   - It says Polybar/Eww/Wired (`README.md:13-15`), while the active install manifest configures Quickshell.
   - This makes expected post-install behavior and troubleshooting misleading.
   - **Fix:** update the architecture summary and add clean-install prerequisites and post-install verification steps.

## Validation performed

- `bash linux/install/tests/sync.test.sh` passed.
- `bash linux/install/tests/manifest.test.sh` passed.

The existing tests validate command construction and a few manifest fields, but do not test a clean-machine bootstrap or whether each selected window-manager config can execute all referenced commands.
