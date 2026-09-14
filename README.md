# Dotfiles

This is a collection of configurations and customizations I've hoarded,
throughout the years, in order to tweak my various desktops into
supporting my preferred workflows.

## Information

<img src="preview.jpg" alt="Rice Showcase" align="right" width="400px">

- Operating System is [Arch Linux](https://archlinux.org/);
- Window Management is handled by [Hyprland](https://github.com/hyprwm/Hyprland);
- Top & Bottom bars are built with [Polybar](https://github.com/polybar/polybar);
- Widgets are built with [Eww](https://github.com/elkowar/eww);
- Notifications are provided by [Wired](https://github.com/Toqozz/wired-notify);
- Window decoration and animations are from [Picom](https://github.com/yshui/picom);
- Wallpapers are by the talented [Byrotek](https://www.patreon.com/byrotek);
- Application Launcher is [rofi](https://github.com/davatorium/rofi);
- Code editing using [NeoVim](https://neovim.io/).

## Installation

Configuration is done through symlinks and relative paths.

```sh
$ git clone --recurse-submodules git@github.com:lukelex/dotfiles.git
$ cd dotfiles && ./linux/install/all
```

For a headless homelab server, run `./linux/install/all --server`. This
installs terminal tooling, OpenSSH, and Docker without an AUR helper, GUI
packages, display services, desktop configuration, or personal Git settings.
Profile packages, groups, and services are defined in
`linux/packages.yaml` and parsed by the bundled static `yq` binary.
The `common` section applies to every profile; profile sections contain only
their additions. Package values list the Unix groups required by that package.
Packages can also declare repository-to-target config links, such as
`linux/config/nvim:$XDG_CONFIG_HOME/nvim`.

Run `./linux/install/all --dry-run` to preview every action without touching
the system. The config stage skips links that would overwrite existing files;
pass `--replace` (e.g. `./linux/install/configs --replace`) to overwrite them.

Run `./linux/install/sync --server` (or `--desktop`) to reconcile a profile.
Each package, group, service, and config-link stage requires confirmation.
Only resources previously recorded under `$XDG_STATE_HOME/dotfiles/install` are
eligible for removal.
