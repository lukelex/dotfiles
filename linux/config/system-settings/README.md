# Portable system preferences

`preferences.json` is the authoritative, versioned configuration for System
Settings. The UI updates this tracked file directly; commit its changes and a
clone of these dotfiles inherits your preferences. No export/import step is
needed. As with the rest of this repo, install at `~/dotfiles` and reconcile the
normal desktop resources/services with dotpkg. Existing installations need a
user `systemctl --user daemon-reload` after updating the service definitions.

The format is plain UTF-8 JSON, two-space indentation, with a `version` field and
named sections. `settings.py` uses only Python's standard library. Reads and
writes validate types, ranges, and names; writes merge under a lock and atomically
replace the file. Invalid edits report an error in Settings and leave the shell's
last valid snapshot active. Fix the file to resume updates.

## Automation

From the repository root:

```sh
python3 linux/config/system-settings/settings.py get
python3 linux/config/system-settings/settings.py get input.repeatRate
python3 linux/config/system-settings/settings.py describe
python3 linux/config/system-settings/settings.py validate
python3 linux/config/system-settings/settings.py set input.repeatRate 40
python3 linux/config/system-settings/settings.py set weather.units '"imperial"'
python3 linux/config/system-settings/settings.py patch '{"display.nightTemperature":3500,"clock.firstDay":0}'
```

Values are JSON (including quotes for strings). `describe` returns the current
data and UI field metadata: key, label, type, range/choices, and supported session.
Use `DOTFILES_PREFERENCES=/absolute/path/preferences.json` for isolated tests or
an explicit alternate configuration; set it in the desktop session environment
so all consumers use the same file. Never write secrets into preferences.

The running shell watches the file, validates changes and updates the UI. It
applies input, idle and night-light backend changes automatically and reports
backend failures inline. Saved preferences remain available for retry/session
restart when a backend is unavailable. Without Quickshell, apply explicitly:

```sh
python3 linux/config/system-settings/settings.py apply input
python3 linux/config/system-settings/settings.py apply idle
python3 linux/config/system-settings/settings.py apply display
```

Input applies on shell startup and after Hyprland config reload; X11's existing
repeat helper also reapplies the saved delay/rate after input resets. Gammastep
and idle launchers read the file on startup, rendering tool-specific configs
under `$XDG_CACHE_HOME/dotfiles/settings/`. Do not edit these generated configs.
The older `gammastep/config.ini` and `hypr/hypridle.conf` describe legacy defaults;
the managed launchers now use preferences.json instead.

## Scope

- **Display:** day/night temperature, sunrise/sunset coordinates, brightness-key
  step, and volume/brightness/layout OSD duration. The night-light on/off action
  remains in Control Center; editing warmth doesn't enable an inactive service.
- **Lock & idle:** Hyprland dim/lock/display-off delays; i3 lock/display-off delays;
  existing fullscreen deferral and Hyprland microphone/camera deferral. A zero
  dim/display-off delay disables that timer. Lock delays remain positive; i3
  requires whole minutes. Deferral applies to idle locking, not explicit locking
  or the lock-before-suspend path. Microphone/camera checks retain the existing
  backend heuristics.
- **Input:** repeat delay/rate on both sessions; Hyprland pointer acceleration,
  sensitivity, mouse/touchpad scrolling, tapping and disable-while-typing.
- **Date & weather:** clock/date formats, first weekday, automatic IP versus fixed
  city (`City,CC`), and metric/imperial weather. Fixed location avoids IP lookup.
  Location/unit changes invalidate weather caches before fetching new values.
- **Desktop & bar:** compact/comfortable sizing, optional hover previews for
  click-accessible panels, and their close grace period. Notification history
  and device privacy hints retain hover access and the bell retains its DND click.
- **Notifications:** global preferences and per-app enabled/sound choices. Current
  preferred values were migrated from local settings. Notification/history content,
  GitHub read markers, and timed DND overrides stay local. Qt's notifications.conf
  remains a runtime mirror for existing consumers; the JSON takes precedence.

Custom notification audio paths refer to files; cloning a path does not copy an
external audio file. Keep shared sounds in the repository when portability matters.

Validation: `node --test linux/config/quickshell/tests/*.test.cjs` exercises the
store with temporary files and mocked backends, never changing live preferences.

## Monitor setups

`monitor-profiles.json` stores named, session-specific layouts and the automatic
switching preference. It includes the existing kanshi setups and imported
autorandr profiles. Each output records its connector, stable identity (EDID on
X11, description on Hyprland), enabled state, mode, refresh rate, scale,
orientation, logical position and X11 primary flag. Connector matching is the
fallback for older profiles without a hardware identity. For duplicate identities,
the saved connector disambiguates; unresolved ambiguity is reported rather than
applying to the wrong display.

The Monitors page selects saved setups, shows which are active/available, lets you
drag displays with edge snapping or enter precise positions, and identifies
physical displays with temporary labels. Saved layouts retain disconnected
devices. Changes stay in a draft until **Apply**; save/update uses the confirmed
layout. Rename/delete only change the profile store. A preferred profile wins
when multiple setups match the same hardware.

**Apply** starts an independent rollback process before touching outputs. You
have 20 seconds to keep the layout; closing Settings or reloading Quickshell does
not cancel the guard. Failed applications and expired confirmations restore the
previous layout. If a dock disappears, recovery uses a remaining connected panel
and, if needed, its advertised mode. The guard retries backend failures. Trial
state, native generated files and temporary manual overrides live in a
session-specific runtime directory, outside Git.

`monitors.py watch` is started by the desktop autostart/i3 config, with a per-session
lock preventing duplicates. It selects native autorandr layouts on X11 and
supervises a generated kanshi config on Hyprland. Between changes it checks cheap
DRM/lid state every three seconds; it does not repeatedly query the display server
on an idle desktop. Existing autorandr postswitch wallpaper/feedback hooks run
after manual confirmation and automatic changes. Gamma and software brightness
are excluded from autorandr application so monitor edits preserve night light.

The manager stops its kanshi child during trials. A kept manual layout remains
until connected hardware changes; automatic switching will not immediately undo
it. An unmanaged kanshi process is reported instead of starting a competing
instance; restart an older Wayland session after updating autostart. The new
autorandr `block` hook prevents distro hotplug invocations of `autorandr --change`
from fighting the manager. Explicit `autorandr --load` remains available. The
manager links the hook if missing and preserves/reports conflicting custom hooks.

```sh
python3 linux/config/system-settings/monitors.py snapshot
python3 linux/config/system-settings/monitors.py validate
python3 linux/config/system-settings/monitors.py import
python3 linux/config/system-settings/monitors.py rename office 'Office dock'
python3 linux/config/system-settings/monitors.py automatic false
python3 linux/config/system-settings/monitors.py details DP-1
```

`save` accepts a profile JSON object, plus an optional existing name to replace.
`apply` accepts an output-array JSON value and returns a trial token; `keep TOKEN`
or `revert TOKEN` resolves that trial. `import` reads existing user autorandr
profiles without overwriting duplicate names; `import-autorandr DIRECTORY` prints
an import preview without writing. `start` starts the manager for the current
session while preserving the existing layout until a hardware change. Use
`DOTFILES_MONITOR_PROFILES` to point all consumers at an alternate complete store.

**Link details** is a read-only, on-demand snapshot. On X11 it shows the current
pixel clock, reported subconnector/link status, and an explicitly labeled 8-bit
RGB bandwidth estimate including blanking. EDID supplies the monitor's advertised
HDMI TMDS limit when present, on either session. This is not negotiated link
capacity: docks, cables, color format/depth, encoding and DSC matter. Unavailable
active color depth, DSC and negotiated capacity remain marked “Not exposed”;
there is no misleading utilization percentage. No debugfs permissions are changed.

Tests cover native config rendering, identity matching, malformed/unsupported
layouts, duplicate monitors, profile preference, manual holds, disabled automation,
independent rollback, partial failures, hot unplug and EDID/link interpretation:

```sh
python3 linux/config/system-settings/test_monitors.py
```
