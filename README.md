<div align="center">

<h1>Dotfiles</h1>

<h3>A considered Linux desktop, built around the way I work.</h3>

<p>Arch Linux · Hyprland / i3 · Quickshell · Neovim</p>

<p><a href="#desktop">Desktop setup</a> · <a href="#screenshots">Screenshots</a> · <a href="#install">Install</a> · <a href="#repository-guide">Repository guide</a></p>

</div>

<br>

<p align="center"><a href="screenshots/desktop.png"><img src="screenshots/desktop.png" alt="Empty i3 desktop with the Quickshell calendar and weather panel open" width="100%"></a></p>

## Desktop

| Component | Setup |
| --- | --- |
| **Window managers** | [Hyprland](https://github.com/hyprwm/Hyprland) on Wayland · [i3](https://i3wm.org/) on X11 |
| **Desktop shell** | [Quickshell](https://quickshell.outfoxxed.me/) bar, panels, notifications, and OSDs |
| **Launchers** | [Fuzzel](https://codeberg.org/dnkl/fuzzel) on Hyprland · [rofi](https://github.com/davatorium/rofi) on i3 |
| **Compositor** | Hyprland effects · [Picom](https://github.com/yshui/picom) for i3 |
| **Editor** | [Neovim](https://neovim.io/) with lazy.nvim |

The configs favor a quiet status surface, quick keyboard workflows, and panels
that reveal detail only when needed. Shared helpers keep the Hyprland and i3
setups familiar across Wayland and X11.

## Screenshots

<table>
  <tr>
    <td width="50%">
      <a href="screenshots/control-center.png"><img src="screenshots/control-center.png" alt="Full desktop with the Quickshell Control Center open" width="100%"></a>
      <p align="center"><sub>Quickshell · Control Center</sub></p>
    </td>
    <td width="50%">
      <a href="screenshots/calion.png"><img src="screenshots/calion.png" alt="Quickshell calendar with weather forecast" width="100%"></a>
      <p align="center"><sub>Quickshell · Calendar and weather</sub></p>
    </td>
  </tr>
</table>

### Fuzzel themes

Three launcher palettes, including a light theme. These are design previews of
the launcher configuration.

<table>
  <tr>
    <td width="33%"><a href="designs/fuzzel/01-slate.png"><img src="designs/fuzzel/01-slate.png" alt="Slate Fuzzel theme preview" width="100%"></a><p align="center"><sub>Slate · default</sub></p></td>
    <td width="33%"><a href="designs/fuzzel/02-graphite.png"><img src="designs/fuzzel/02-graphite.png" alt="Graphite Fuzzel theme preview" width="100%"></a><p align="center"><sub>Graphite · compact</sub></p></td>
    <td width="33%"><a href="designs/fuzzel/03-porcelain.png"><img src="designs/fuzzel/03-porcelain.png" alt="Porcelain light Fuzzel theme preview" width="100%"></a><p align="center"><sub>Porcelain · light</sub></p></td>
  </tr>
</table>

## Install

The desktop configuration expects the repository at **`$HOME/dotfiles`** on
Arch Linux.

```sh
git clone --recurse-submodules git@github.com:lukelex/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./linux/install/sync
```

For a headless server, use `./linux/install/all --server`. For a specific
machine, pass a committed host overlay, for example:

```sh
./linux/install/sync --host <name>
```

## Repository guide

- [`linux/packages.yaml`](linux/packages.yaml) — desktop and server package selections, config links, and services.
- [`linux/install/`](linux/install/) — sync, full setup, verification, and supporting installer steps.
- [`linux/config/`](linux/config/) — application and desktop configurations.
- [`linux/scripts/`](linux/scripts/) — system helpers, installed as `u_*` commands on desktop setups.
- [`linux/hosts/README.md`](linux/hosts/README.md) — host overlay format.
- [`linux/config/fuzzel/README.md`](linux/config/fuzzel/README.md) — launcher themes and shortcuts.

<details>
<summary><strong>How installation works</strong></summary>

`sync` reconciles packages, groups, config links, services, and remote bundles
from the selected profile using the pinned `dotpkg` binary. It symlinks
`$XDG_CONFIG_HOME/dotpkg/package.yaml` to the tracked `linux/packages.yaml`;
dotpkg stores machine-local state beside that link.

Preview the reconciliation with:

```sh
./linux/install/sync --dry-run
```

The first run can still bootstrap `yay` and initialize dotpkg's local manifest
and state. Existing local manifests are backed up before linking to the
repository version. Pulling repository changes updates the manifest on each
linked machine. Config conflicts are preserved unless `--replace` is passed. Use
`./linux/install/all` to include system setup, post-install steps, and
verification, or `./linux/install/verify` to check an existing setup.

For package and resource maintenance, see `dotpkg --help`.
`dotpkg clean --resources` removes stale, unchanged managed bundles and other
stale managed resources; `dotpkg recover` handles an interrupted package
transaction.

OpenCode's global config is linked by dotpkg on desktop and server profiles.
It loads repository skills from `~/dotfiles/.opencode/skills` and declares a
remote file bundle for `skills/grill-me`, `skills/grilling`, and `LICENSE` from
`mattpocock/skills`. dotpkg copies those requested paths into
`~/.local/share/dotpkg/opencode-skills` without running them. Invoke the skill
with `@grill-me`. Every full `sync --resources` checks the upstream default
branch and updates the managed directory only if its commit or content changed;
an optional 40-character `commit` in `resources.remote_bundles` freezes it.
An unavailable upstream is an error, not a no-op. `--packages-only` skips
remote bundles. On existing machines, run
`./linux/install/sync` once to link the manifest; subsequent repository pulls
update its declarations directly. Keep the vendored
copies until the pinned dotpkg release is updated and the managed installation
is verified, then remove them to avoid duplicate skill IDs. The declaration is
not active with the current pinned binary until that release update lands.

### Webcam reactions

Desktop syncs install checksum-pinned OpenEffects 0.1.4 native packages (x86_64)
before dotpkg links its settings and enables its user service on `default.target`.
The GTK preview dependency is declared in the manifest. Reactions are enabled,
the physical camera is autodetected, and capture/effects processing stops when
no application consumes the virtual camera. OpenEffects is managed by pacman,
not dotpkg's package-clean stage, until an upstream package origin is available.

To migrate an existing install, review your local manifest before running:

```sh
./linux/install/sync --refresh-manifest --replace
```

Refreshing backs up the local manifest; `--replace` can replace conflicting
config paths across the desktop profile. Chrome is the shared default browser;
its managed `chrome-flags.conf` enables PipeWire camera support. Fully quit and
reopen Chrome after applying it, then select OpenEffects Virtual Camera in your
calling app.

Microsoft Edge is **not installed**. The `archqms` host overlay additionally
links its flags file for an independently installed Edge. On that machine use
`./linux/install/sync --host archqms --refresh-manifest --replace` and fully quit
and reopen Edge after applying it.

</details>
