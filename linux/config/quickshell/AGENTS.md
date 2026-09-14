# Quickshell Design And Engineering Guide

This directory implements the desktop bar, its panels, notifications, and system
OSDs. Use this guide for future changes alongside the repository's root AGENTS.md.
The supported live environment is i3/X11; do not assume Wayland behavior applies.

## Design Intent

The bar is a quiet status surface, not a dashboard. Show enough to understand the
desktop at a glance, reveal useful detail on hover, and require deliberate actions
for changes. Prefer the Principle of Least Surprise over novelty or decoration.

- Every permanent bar element must earn its space through frequent use or meaningful status.
- Put names, lists, percentages, and infrequent actions in panels rather than adding persistent bar labels. Existing time/date labels are intentional exceptions.
- Use progressive disclosure: overview first, common actions next, advanced setup in existing system tools. Avoid tabs or extra clicks for the primary use case.
- Minimalism means fewer decisions and less distraction, not missing feedback, ambiguous icons, tiny hit targets, or hidden errors.
- Keep one UI and one source of state per capability. Multiple entry points should open the same panel, not become competing implementations.
- Connectivity owns Wi-Fi, Bluetooth, and VPN controls. Control Center owns local device adjustments: volume/mute and brightness/night mode first, battery and power profile together, then session locking. Do not reintroduce network shortcut tiles there.
- Date/time is calendar-first, with weather as supporting information, not a profile dashboard. Keep month navigation, a Today action when browsing away, a stable Monday-first six-week grid, and a distinct today highlight. Reset to the current month on a fresh opening, not while the user is browsing. Do not imply date selection or events without an actual action/integration.
- Do not add widgets, settings, abstractions, or configurable options merely because they might be useful later.

## Visual Language

- Reuse the theme colors in `Bar.qml` (`controlBackground`, `controlSurface`, `controlPrimaryText`, `controlSecondaryText`, `controlActive`, and related tokens). Support both light and dark themes.
- Use `LucideIcon.qml` and SVGs in `../lucide/svg/`. Verify each asset exists; preserve its license when adding variants.
- Use the controller's `fontFamily` and `barFontSize`; do not introduce another font family or independent bar icon sizing. Current defaults are Hack Nerd Font Mono and 17px.
- Preserve the existing layout: workspaces left, time/date centered, compact status/actions right. Current bar height is 40px.
- Follow the established panel proportions: approximately 432px wide, 12px below the bar, 16px content padding, 26px outer corners, and smaller rounded inner surfaces. Treat these as shared defaults, not an excuse to ignore screen bounds.
- Use muted styling for inactive state, restrained blue for active state, and warning color for conditions that genuinely need attention. Do not convey important distinctions through color alone.
- Keep short status text legible and detailed lists bounded. One long list must not push another section's overview out of reach.
- Avoid decorative gradients, oversized headings, constant motion, redundant borders, and dashboard-style tiles without a functional purpose.

## Interaction Contract

- Hover previews must not steal keyboard focus. Allow enough time to cross the gap into a popup; connectivity uses a local 500ms grace period. Cancel delayed closure when the pointer returns.
- A click can pin a detail panel for deliberate interaction. A pinned panel must support Close, Escape, and outside-click dismissal; leaving it with the pointer must not close it.
- Preserve existing explicit bar shortcuts unless asked to change them; for example, clicking the notification bell toggles DND. Do not silently redefine all bar clicks as pinning.
- Opening a panel should close sibling panels and cancel stale close requests. Route actions and timers to the actual screen's panel, not an assumed primary-screen instance.
- Separate navigation from state changes. Clicking a network name selects a connection; only its explicit radio switch turns Wi-Fi off. Give icons generous hit areas without overlapping neighboring controls.
- Show pending state immediately, prevent competing duplicate actions, and report success only after backend confirmation. Errors belong near the attempted action.
- Preserve the reader's place. Removing an item must not rebuild unrelated list rows, jump to the top, collapse surviving expanded groups, or reorder targets under the pointer.
- Anchor list updates to a surviving visible item and its viewport offset when layout changes require compensation. Clamp only to the remaining scroll range, and never fight manual scrolling.

## Motion And Notifications

- Animate to explain a state transition, not to decorate it. Existing panel entry/exit timings are roughly 160/120ms; notification dismissals are roughly 180-260ms. Keep transitions short and consistent with their neighbors.
- Cancel opposing animations when reversing direction. Repeated open/close requests must be safe, including requests made during an exit.
- Keep a departing visual alive until its exit finishes, then remove it and reconcile service state. Capture the target ID before animation; arrivals must not change what gets dismissed.
- Handle bursts together instead of building a serial animation backlog. Avoid unnecessary persistence writes, model rebuilds, and hidden-panel work.
- Group consecutive notifications only when app and urgency match. Never jump back to an older matching stack across an intervening mismatch. Live popups also have an existing time-window constraint.
- Hover protects cards from both timeout and capacity eviction. New cards joining a hovered stack inherit that protection.
- Clear All acts on a snapshot taken at the click. Later arrivals and independent volume/brightness OSDs must survive.
- Notification dismissal is routine housekeeping, not deletion of the underlying message. Use a subdued `x` with a generous hit target, neutral hover feedback, and a descriptive tooltip/accessibility label for cards and groups; use a separate "Clear all" text action for history. Keep exits slide-and-fade without red trash-reveal layers.
- Keep system OSDs distinct from notification history. Release references when native notifications close; do not invoke methods on destroyed objects.
- System notification senders should supply a specific icon with `notify-send -i` (for example, `$LUCIDE_PATH/battery-charging.svg`), rather than relying on the generic `System` app name. The shared `NotificationService.iconFor()` resolver preserves sender-selected variants and routes this repository's Lucide SVGs through theme-colored rendering. Keep explicit imagery ahead of semantic fallbacks and never recolor arbitrary application icons or avatars.
- Notification icons can already be `image://icon/...` or other native image-provider URLs; preserve them rather than resolving them again as theme names. Quickshell's `Qt.resolvedUrl()` can block paths outside the shell directory, so the sibling Lucide assets use the repository's installed `$HOME/dotfiles` location.
- Respect explicit persistent timeouts. The installed Quickshell 0.3.1 build was live-verified to expose notification timeouts in milliseconds despite conflicting documentation; verify units again when changing versions.

## Architecture And Platform

- `shell.qml` composes the shell. `Bar.qml` owns shared visual tokens and per-screen panel wiring.
- i3 starts Quickshell through `linux/scripts/quickshell --session-start`: validate the live socket/display, import only `DISPLAY`, `I3SOCK`, and optional `XAUTHORITY`, then start the systemd user service. Repeated calls use `start`, not `restart`. The unit is linked but not enabled on `default.target`; starting before the graphical session caused a 30-second socket wait and a restart delay. Do not restore boot-time enablement or import the entire login environment.
- `*Center.qml` files own panel presentation and interaction. `NotificationService.qml` and `ConnectivityService.qml` own backend state and lifecycle; do not duplicate their state through independent polling in a panel.
- `WeatherService.qml` owns one shared weather snapshot from `u_weather snapshot`; retain the helper's existing CLI modes for other consumers. The helper validates payloads before replacing its 20-minute cache, preserves valid cached data on failure, and bounds requests with a cooldown. Expose loading, freshness, update time, and errors honestly; a retry button must indicate when cooldown prevents action.
- Forecast low/high values aggregate complete three-hourly coverage of each of the next three city-local dates, using the provider's UTC offset. Do not label noon samples as daily ranges or silently fill gaps with later days. Use condition-specific icons and display partial/stale data as such.
- Weather credentials come from `OPEN_WEATHER_API_KEY`, with the existing `~/Dropbox/secrets.env` as fallback when absent from the desktop service environment. Never embed or log the key. Weather tests use isolated fixture caches and mocked requests, not the user's secrets or live cache.
- Prefer native, event-driven Quickshell modules when available. Connectivity uses `Quickshell.Networking` over NetworkManager and `Quickshell.Bluetooth` over BlueZ. Do not bypass NetworkManager by controlling its iwd backend directly.
- Activate saved Wi-Fi profiles without an explicit disconnect first. Keep available saved networks active-first, then in stable name/device order, not constantly changing signal-strength order.
- Enable Wi-Fi scanning only while the connectivity panel is open. Do not continuously discover Bluetooth devices just to show connected-device batteries.
- Bluetooth battery and native Wi-Fi strength values are fractions (0-1). Check `batteryAvailable`; unavailable battery data is not 0%.
- Delegate advanced networking and pairing to `nm-connection-editor` and `blueman-manager`. Release popup grabs before opening another application.
- On Quickshell 0.3.1/X11, `PopupWindow.grabFocus` alone does not reliably implement keyboard/pointer grabs. `ConnectivityCenter.qml` uses a non-grabbing hover preview and `Controls.Popup.Window` for the pinned view, sharing one content item. Preserve this distinction unless a replacement is live-verified.
- DateTimeCenter uses that same preview/pinned distinction with a screen-local 600ms close timer. Both bar date/time entry points must route to the actual screen's instance; do not restore the old primary-screen delayed-close shortcut. At narrow widths, stack weather below the calendar and constrain height with scrolling.
- In `../picom.conf`, allow background blur for both Quickshell tooltip previews and normal pinned windows. Excluding tooltip windows makes the same panel visibly change blur when pinned; keep the dock/bar exclusion separate.
- During date/time promotion, keep a snapshot in the preview above the destination until the destination's first `frameSwapped`. Qt's `opened` signal and QML visibility/opacity values alone do not prove a populated frame has reached the screen; test first-click transitions with rendered-frame capture, not only mocked lifecycle tests.
- Prefer the smallest correct change. Extract shared code when there is actual reuse, not to build a generic widget framework. Do not add compatibility fallbacks without a concrete supported consumer.

## Validation And Safe Development

Commands below run from the repository root:

```sh
node --test linux/config/quickshell/tests/*.test.cjs
/usr/lib/qt6/bin/qmllint linux/config/quickshell/ConnectivityCenter.qml
git diff --check -- linux/config/quickshell linux/config/lucide
quickshell list --all
quickshell log --pid <current-pid> --tail 30
```

- Run Qt 6's linter on every changed QML file. `/usr/bin/qmllint` may select an older Qt version and fail without useful diagnostics. Native Quickshell type metadata can produce unresolved-type warnings; inspect and report them rather than calling a warning-producing run clean.
- The Node tests extract JavaScript from QML and mock native services. They cover logic, not QML bindings, rendering, focus, D-Bus delivery, or actual hardware behavior.
- Startup tests exercise the launcher with isolated Unix sockets and mocked system commands. For startup changes, also validate the unit and i3 config, check boot journal timestamps and restart counts, and distinguish a measured live restart from an actual reboot/login test.
- Inspect installed `.qmltypes` under `/usr/lib/qt6/qml/Quickshell/` and matching upstream source when API behavior is uncertain. Confirm units and lifecycle semantics rather than relying on names or documentation alone.
- Configs are symlinked and Quickshell reloads on edits. Check the current instance and its logs; do not launch a second full shell or run provisioning scripts just to validate a component.
- Confirm the reload log timestamp is newer than the edit before live-testing. Atomic file replacement by a formatter can leave the running instance watching an old inode; an edit to the shell entry point can trigger a fresh reload and restore component watches. Do not infer that new code loaded from an old "Configuration Loaded" message.
- For UI changes, exercise hover-to-panel traversal, pinning, Escape/outside closure, sibling-panel changes, rapid reversal, and list updates. Check light/dark appearance and relevant screen sizes; multi-monitor behavior needs explicit verification.
- For notifications, check arrivals during dismissal, burst expiry, hovered cards, Clear All snapshots, and reading position midway through and near the bottom of history.
- Do not toggle radios, switch networks, pair devices, clear real notification history, or change system settings merely to test without user approval. Use mocks or narrowly scoped synthetic data, and disclose what was not live-tested.
- Remove temporary IPC diagnostics, test notifications, and screenshots. Preserve unrelated worktree changes and never commit credentials, personal state, screenshots, or unresolved conflicts.
- Update this guide when an intentional design decision changes; do not turn it into a session log or freeze incidental implementation details as permanent requirements.
