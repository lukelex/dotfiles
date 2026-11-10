# Screen-share picker

XDPH runs `u_hypr-share-picker.py` from `xdph.conf`. The desktop manifest manages
the link in `~/.local/bin`; its target is `linux/config/hypr/share-picker.py`.
GTK 4, python-gobject and grim are
declared dependencies. Changes to the script apply to the next share request.
Changes to `xdph.conf` require restarting `xdg-desktop-portal-hyprland.service`.

## Health check

```sh
u_hypr-share-picker.py --check
```

Run inside the Hyprland session. Checks the installed link, portal configuration,
GTK/display access, commands, Hyprland IPC, and actual monitor/window capture.
Captures stay in memory. The command does not open a sharing session.

Diagnostics are JSON on stderr, normally captured by the portal's user journal:

```sh
journalctl --user -u xdg-desktop-portal-hyprland
```

The picker never logs window titles, screenshots or selection identifiers.
XDPH itself may log its normal selection metadata.

## Failure behavior

- A supervisor isolates GTK errors/native crashes and validates the response.
  On failure it replaces itself with `hyprland-share-picker`. Cancel emits no
  response and never opens a fallback. “Use standard picker” explicitly switches.
- At most three capture jobs run concurrently. Each capture has a three-second
  timeout and one retry. Closing kills active captures and cancels queued jobs.
- Missing previews do not prevent selection. Captures are direct window snapshots
  using `stableId`, not monitor crops. Titles and workspace names update regularly.
- Closed/disconnected sources are disabled and selection is revalidated. A window
  address reused by a different stable ID is rejected. Unknown identity requires
  the standard picker rather than guessing from a title.
- Portal handles are a fixed snapshot for each request. New windows require
  reopening the share dialog; we cannot generate new portal handles in this helper.
- Browser permission dialogs and restore-token behavior remain browser-controlled.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s linux/config/hypr/tests -v
SHARE_PICKER_GUI_TESTS=1 PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s linux/config/hypr/tests -v
```

The second command requires a live Hyprland session. It briefly opens picker
windows, exercises concurrent instances, real snapshots and selection validation,
and opens a real XDG ScreenCast request that it cancels by closing the picker.
It does not transmit screen content to another app.

Also manually verify Chrome sharing and stopping, unplugging an output, closing
a source during selection, and mixed-scale multi-monitor setups when available.
Geometry/Unicode unit tests are not a substitute for those hardware tests.

## Other capture strategies

Quickshell's `ScreencopyView` supports native window snapshots and live previews.
It is a future alternative if live previews are wanted; it would still need the
portal-handle mapping, supervisor, cancellation and lifecycle guarantees above.
The current direct `grim -T` path is verified on this machine and avoids a UI
rewrite. Coordinate crops, raising windows to capture them, and per-thumbnail
portal requests are deliberately avoided. No persistent screenshot cache is used.
