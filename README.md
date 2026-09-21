# Dotfiles

This is a collection of configurations and customizations I've hoarded,
throughout the years, in order to tweak my various desktops into
supporting my preferred workflows.

## Information

<img src="preview.jpg" alt="Rice Showcase" align="right" width="400px">

- Operating System is [Arch Linux](https://archlinux.org/);
- Window management is handled by [Hyprland](https://github.com/hyprwm/Hyprland) or [i3](https://i3wm.org/);
- The bar, control center, and notifications are built with [Quickshell](https://quickshell.outfoxxed.me/);
- Window decoration and animations are from [Picom](https://github.com/yshui/picom);
- Wallpapers are by the talented [Byrotek](https://www.patreon.com/byrotek);
- Application launchers are [rofi](https://github.com/davatorium/rofi) for i3 and [tofi](https://github.com/philj56/tofi) for Hyprland;
- Code editing using [NeoVim](https://neovim.io/).

## Installation

Configuration is done through symlinks and relative paths.

```sh
$ git clone --recurse-submodules git@github.com:lukelex/dotfiles.git "$HOME/dotfiles"
$ cd "$HOME/dotfiles" && ./linux/install/sync
```

The desktop configuration uses `$HOME/dotfiles` at runtime; install this
repository at that path.

For a headless homelab server, run `./linux/install/all --server`. `sync`
reconciles only the declarative manifest; `all` also applies every active
imperative setup concern and runs post-install verification.
Profile packages, AppImages, groups, config links, and services are reconciled
by the pinned static `dotpkg` binary. On first use, the repository's
`linux/packages.yaml` seed is copied to dotpkg's per-user manifest at
`$XDG_CONFIG_HOME/dotpkg/package.yaml`; state is kept beside it in
`state.yaml`.
The `common` section applies to every profile; profile sections contain only
their additions. The root `source: aur` makes `yay` the default resolver; it
also resolves official repository packages. A package can override this with a
`source` child when needed. Package values can list Unix groups required by
that package.
Packages can also declare repository-to-target config links, such as
`linux/config/nvim:$XDG_CONFIG_HOME/nvim`.
The first interactive desktop sync records its package selections locally. Use a
committed `linux/hosts/<name>.yaml` overlay with `--host <name>` for additional
machine-specific package metadata. See `linux/hosts/README.md` for the overlay
format.

Run `./linux/install/sync --dry-run` to preview changes without touching the
system. It initializes dotpkg and migrates the legacy state file on first use.
Config links and services are reconciled by dotpkg; conflicting targets are
preserved unless `--replace` is passed.

Run `./linux/install/sync --server` (or `--desktop`) to reconcile a profile.
Each package, group, service, and config-link stage requires confirmation.
Only resources previously recorded in dotpkg's adjacent `state.yaml` are
eligible for removal.

Existing installs keep their local manifest so package selections and local
changes are not overwritten. Run `./linux/install/sync --refresh-manifest` to
adopt the repository's current `packages.yaml`; the previous local manifest is
saved beside it with a timestamped `.bak` suffix.

After syncing, run `./linux/install/verify` to check that the selected desktop
configuration, helper links, and window-manager dependencies are available.

One-off setup that cannot be expressed as manifest resources (user directories,
login shell, timezone, font/cache refreshes) is collected in
`./linux/install/post`.

Run `dotpkg validate [--host <path>]` to verify selected manifest packages.
Repository packages use local pacman sync databases and AUR packages use
batched AUR RPC requests.

Existing package metadata remains supported: `groups`, `configs`, and
`services` declared on package entries are reconciled by the standalone sync.
Use top-level `resources.configs` and `resources.services` for custom resources
that are not owned by a package.

Pinned AppImages can be declared as package entries with `source: appimage`, an
HTTPS release address, and a `sha256` digest. Dotpkg verifies and tracks these
artifacts alongside package reconciliation.

Use dotpkg directly for package operations:

```sh
dotpkg add <name> --scope desktop --resources --root "$HOME/dotfiles"
dotpkg diff --resources --root "$HOME/dotfiles"
dotpkg doctor --resources --root "$HOME/dotfiles"
dotpkg clean --yes
dotpkg recover --yes
```

Use `dotpkg clean --yes` only to remove stale managed packages. Use
`dotpkg recover --yes` after an interrupted transaction with a pending journal.
