# Quickshell Design And Engineering Guide

This directory implements the desktop bar, its panels, notifications, and system
OSDs. Use this guide for future changes alongside the repository's root AGENTS.md.
The configuration supports i3/X11 and Hyprland/Wayland. Validate behavior in each
session; X11-specific window-management workarounds do not automatically apply to
Wayland.

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
- Use the controller's `fontFamily` and `barFontSize`; do not introduce another font family or independent bar icon sizing. Current defaults are Hack Nerd Font Mono and 18px.
- Preserve the existing layout: workspaces left, time/date centered, compact status/actions right. Current bar height is 40px.
- Control Center and Connectivity use panels up to 432px wide; the calendar and GitHub reviews need more space. Panels sit 12px below the bar with roughly 16px content padding and rounded surfaces. Constrain them to the screen bounds.
- Use muted styling for inactive state, restrained blue for active state, and warning color for conditions that genuinely need attention. Do not convey important distinctions through color alone.
- Use `controlBorder` for panel outlines, `controlSurfaceBorder` for bordered rows/cards, and `controlHover` for neutral hover feedback. Blue indicates selection or enabled state, not an ordinary hover. Panel headings are 16px; close controls use a 32px target, 16px icon, and 10px-radius neutral surface.
- Muting and DND are intentional states, not warnings: use a muted volume icon and “Muted” OSD label, and a blue `bell-off` for DND. Notification stack counts remain secondary text.
- Media artwork intentionally keeps a dark scrim and light text in both themes; clip the entire artwork card to its rounded outline and keep transport hover feedback legible on that scrim.
- Battery icons use critical at 0–14%, low at 15–39%, medium at 40–64%, high at 65–89%, and full at 90–100%; charging has its own icon.
- Keep short status text legible and detailed lists bounded. One long list must not push another section's overview out of reach.
- Avoid decorative gradients, oversized headings, constant motion, redundant borders, and dashboard-style tiles without a functional purpose.

## Interaction Contract

- Hover previews must not steal keyboard focus. Allow enough time to cross the gap into a popup; connectivity uses a local 500ms grace period. Cancel delayed closure when the pointer returns.
- A click can pin a detail panel for deliberate interaction. A pinned panel must support Close, Escape, and outside-click dismissal; leaving it with the pointer must not close it.
- Preserve existing explicit bar shortcuts; clicking the notification bell toggles DND.
- The bar's Resize badge sits beside workspaces only while i3's resize mode or Hyprland's resize submap is active. i3 needs an explicit `I3IpcListener` mode subscription; `I3.rawEvent` only subscribes to workspace/output events. Query binding state after subscription to restore the badge on shell reload without overriding newer mode events.
- Hyprland uses native `submap` events and a one-shot `hyprctl -j submap` query (a JSON string) after IPC initialization, on shell reload, and on compositor config reload. Both resize modes support H/J/K/L and arrows, with Escape or Enter to exit; mode events take precedence over in-flight state queries.
- Keyboard entry points are available through i3/Hyprland shortcuts: calendar (`Super+Ctrl+T`), connectivity (`Super+Ctrl+W`), audio output (`Super+Ctrl+V`), and Do Not Disturb (`Super+Ctrl+M`). Keep the bar `PanelWindow` non-focusable; the first three open the focused monitor's existing pinned, focusable panel, while DND toggles directly. Escape from a pinned panel returns focus to the previous application.
- Opening a panel should close sibling panels and cancel stale close requests. Route actions and timers to the actual screen's panel, not an assumed primary-screen instance.
- Separate navigation from state changes. Clicking a network name selects a connection; only its explicit radio switch turns Wi-Fi off. Give icons generous hit areas without overlapping neighboring controls.
- Show pending state immediately, prevent competing duplicate actions, and report success only after backend confirmation. Errors belong near the attempted action.
- Preserve the reader's place. Removing an item must not rebuild unrelated list rows, jump to the top, collapse surviving expanded groups, or reorder targets under the pointer.
- Anchor list updates to a surviving visible item and its viewport offset when layout changes require compensation. Clamp only to the remaining scroll range, and never fight manual scrolling.

## Motion And Notifications

- Animate to explain a state transition, not to decorate it. Existing panel entry/exit timings are roughly 160/120ms; notification dismissals are roughly 180-260ms. Keep transitions short and consistent with their neighbors.
- Critical notification attention cues run once while visible rather than looping; the warning styling remains after the cue. OSDs use the same panel surface/outline and restrained 160/120ms easing, without a spring overshoot.
- Cancel opposing animations when reversing direction. Repeated open/close requests must be safe, including requests made during an exit.
- Keep a departing visual alive until its exit finishes, then remove it and reconcile service state. Capture the target ID before animation; arrivals must not change what gets dismissed.
- Handle bursts together instead of building a serial animation backlog. Avoid unnecessary persistence writes, model rebuilds, and hidden-panel work.
- Group consecutive notifications only when app and urgency match. Never jump back to an older matching stack across an intervening mismatch. Live popups also have an existing time-window constraint.
- Hover protects cards from both timeout and capacity eviction. New cards joining a hovered stack inherit that protection.
- Clear All acts on a snapshot taken at the click. Later arrivals and independent volume/brightness OSDs must survive.
- Notification dismissal is routine housekeeping, not deletion of the underlying message. Use a subdued `x` with a generous hit target, neutral hover feedback, and a descriptive tooltip/accessibility label for cards and groups; use a separate "Clear all" text action for history. Keep exits slide-and-fade without red trash-reveal layers.
- Keep system OSDs distinct from notification history. Release references when native notifications close; do not invoke methods on destroyed objects.
- System notification senders should supply a specific icon with `notify-send -i`. `NotificationService.iconFor()` prefers sender-selected imagery over semantic fallbacks, colors only this repository's Lucide SVGs, and preserves native image-provider URLs.
- Never persist or replay transient notification images (`image://qsimage/...` pixmaps or Chromium `scoped_dir` temp files); use a durable icon for saved history. Keep fallback resolution for theme icons that Quickshell has not yet cached.
- Respect explicit persistent notification timeouts; verify the installed Quickshell version's timeout units when changing this behavior.

## Architecture And Platform

- `shell.qml` composes the shell. `Bar.qml` owns shared visual tokens and per-screen panel wiring.
- Both window managers start Quickshell through `linux/config/quickshell/scripts/quickshell --session-start`. The launcher validates the active session's socket/display, imports only its environment into the user manager, and starts the shared systemd user service. The unit is linked but not enabled on `default.target`.
- Runtime helpers the shell invokes live beside the config in `linux/config/quickshell/scripts/` and are called by absolute path (`scripts/battery`, `scripts/nightmode`, `scripts/weather`, plus this launcher), never through the global `u_*` links that `linux/install/binaries` creates for `linux/scripts/`. Keep the quickshell stack self-contained; do not move its helpers back to `linux/scripts/`.
- `*Center.qml` files own panel presentation and interaction. `NotificationService.qml` and `ConnectivityService.qml` own backend state and lifecycle; do not duplicate their state through independent polling in a panel.
- `WeatherService.qml` owns one shared weather snapshot from `scripts/weather snapshot`; the helper also supports `icon`/`show`/`details`/`forecast` for manual use. The helper validates payloads before replacing its 20-minute cache, preserves valid cached data on failure, and bounds requests with a cooldown. Expose loading, freshness, update time, and errors honestly.
- Forecast low/high values aggregate complete three-hourly coverage of each of the next three city-local dates, using the provider's UTC offset. Do not label noon samples as daily ranges or silently fill gaps with later days. Use condition-specific icons and display partial/stale data as such.
- Weather credentials come from `OPEN_WEATHER_API_KEY`, with the existing `~/Dropbox/secrets.env` as fallback when absent from the desktop service environment. Never embed or log the key. Weather tests use isolated fixture caches and mocked requests, not the user's secrets or live cache.
- Prefer native, event-driven Quickshell modules when available. Connectivity uses `Quickshell.Networking` over NetworkManager and `Quickshell.Bluetooth` over BlueZ. Do not bypass NetworkManager by controlling its iwd backend directly.
- Audio status uses tracked `Quickshell.Services.Pipewire` default nodes for live volume and mute state; PipeWire default-device changes refresh the open audio picker immediately. Keep `AudioService`'s `pactl` selection and stream migration behavior intact.
- Control Center exposes output and microphone volume/mute. The sound-device picker shows the selected microphone's mute state and a native `PwNodePeakMonitor` level meter; enable capture monitoring only while the picker is visible and the microphone is unmuted. Microphone notifications are transient system OSDs, not notification history.
- Audio sliders coalesce edits in 30ms windows against the captured native PipeWire node. Cancel queued edits and confirmation state when the default node changes or disappears; never resolve a queued edit against a replacement default. Native UI volume/mute changes emit OSDs only after state confirmation, with timeout errors in Control Center. Keyboard helpers emit their own OSDs; do not add duplicate notifications at callers.
- `AudioService` carries the selected microphone's mute state across default-input switches, disconnect/reconnect gaps, and config reloads using shared `PersistentProperties`. Observe external changes on the selected input so keyboard shortcuts and `pavucontrol` update the same intent; ignore stale state while a carried change is pending. A fresh shell process seeds its intent from the current device state. The separate Mute all microphones action also mutes newly arriving input nodes until the selected microphone is explicitly unmuted; releasing this policy leaves other inputs muted. Native source tracking must exclude playback monitors and application streams, and must not activate capture.
- Audio device-list changes trigger a debounced refresh while the picker is open, with a five-second reconciliation fallback. `scripts/audio-switch` sets the default and moves existing streams; partial migration failures remain visible after default-device confirmation, while streams that ended during migration are harmless.
- The sound picker uses concise device labels while retaining original backend names for routing. Its Advanced sound settings action releases the popup before launching `pavucontrol` for application routing, ports, and profiles.
- `TodayCenter` places the quote between the calendar/weather and the MPRIS player. Its active card uses dimmed cover art for legible track details and a prominent playback control; up to two inactive players appear as horizontally browsable artwork pills showing track and artist below it. Skip empty tracks and duplicate media from browser instances before limiting the alternatives. Switching pauses the previous source when supported, then raises and starts the chosen player when possible. Keep controls capability-aware and responsive on narrow screens.
- Show MPRIS elapsed/total time and progress only when both position and length are supported. Refresh position once per second only while the popup is open and playing; seek by setting position only when `canSeek` is true.
- Battery status, time estimates, and health use the laptop `UPower.displayDevice` and its change signals; convert `UPowerDevice.percentage` from its 0–1 fraction to a displayed percentage. `UPower.onBatteryChanged` drives cable notifications and the battery helper handles threshold warning persistence. Discharging batteries issue audible critical warnings at 14%, 10%, and 5%, once per level per discharge cycle. Use native `PowerProfiles` state and degradation reasons when its D-Bus service is available, retaining the firmware profile helper as fallback.
- Activate saved Wi-Fi profiles without an explicit disconnect first. Keep available saved networks active-first, then in stable name/device order, not constantly changing signal-strength order.
- Ethernet has one row per adapter when multiple are present. Its switch changes only that adapter's autoconnect/connection; keep requests pending until native state confirms them, with failure signals and a 45-second timeout. Distinguish unplugged, disconnected, connecting and unmanaged states.
- `VpnService` owns NordVPN commands and status independently of local control polling. Bound CLI requests with timeouts, surface errors in Connectivity, keep unknown status distinct from disconnected, and retain pending state until a post-command query confirms the requested state/location. Ignore pre-action status responses; reconcile while open or pending.
- VPN destination is selectable before connecting. The switch uses that choice; while connected, Apply deliberately changes location. Show the current location in status, preserve unapplied selections during refreshes, and otherwise synchronize the destination to the confirmed country.
- Connectivity's heading reports NetworkManager's system-wide internet status separately from device link state. Disabled/unsupported checks remain unknown; do not enable checks or infer internet access from link state or traffic counters.
- Control Center's battery card matches the adjustments/system surfaces (18px radius, 14px padding): icon/title and right-aligned percentage, then left-aligned charging/discharging wattage and right-aligned time estimate on the same line, with health details below. Keep the power-profile control directly below. Use the magnitude of native `UPower.displayDevice.changeRate` in watts and its change signal; label direction from device state. Zero or invalid rates are unavailable, and inactive charging states hide the rate. This measures battery power, not total adapter output.
- Place a 6px charge-level bar between the battery header and wattage, matching system metric tracks. Use neutral fill normally and warning color below 15%; an empty battery has no fill, and high charge is not a warning.
- Enable Wi-Fi scanning only while the connectivity panel is open. Do not continuously discover Bluetooth devices just to show connected-device batteries.
- Connectivity samples `/proc/net/dev` once per second only while its panel is open. Center each connection type's rates inside its active device row, upload above download, preserving the normal row height and left-hand device label. Use the opaque surface with primary text and green download/purple upload arrows. Sum only that type's connected NetworkManager interfaces, excluding VPN/loopback duplication; display bytes per second and use an unavailable placeholder until two valid samples arrive.
- Bluetooth battery and native Wi-Fi strength values are fractions (0-1). Check `batteryAvailable`; unavailable battery data is not 0%.
- Delegate advanced networking and pairing to `nm-connection-editor` and `blueman-manager`. Release popup grabs before opening another application.
- `TodayCenter.qml` and `ConnectivityCenter.qml` use anchored `PopupWindow` surfaces for hover and pinned views, with focus grabbing only while pinned. During pin promotion, retain the preview snapshot until the destination's first `frameSwapped` to avoid a visible blink.
- TodayCenter uses that same preview/pinned distinction with a screen-local 600ms close timer. Both bar date/time entry points route to the actual screen's instance. At narrow widths, stack weather below the calendar and constrain height with scrolling.
- On i3, `../picom.conf` allows background blur for both Quickshell previews and pinned panels while excluding the bar. Test first-click pin transitions with rendered frames, not only lifecycle mocks.
- Prefer the smallest correct change. Extract shared code when there is actual reuse, not to build a generic widget framework. Do not add compatibility fallbacks without a concrete supported consumer.

## Validation And Safe Development

Commands below run from the repository root:

```sh
node --test linux/config/quickshell/tests/*.test.cjs
/usr/lib/qt6/bin/qmllint linux/config/quickshell/Bar.qml
git diff --check -- linux/config/quickshell linux/config/lucide
quickshell list --all
quickshell log --pid <current-pid> --tail 30
```

- Run Qt 6's linter on every changed QML file (substitute its path in the example). `/usr/bin/qmllint` may select an older Qt version and fail without useful diagnostics. Native Quickshell type metadata can produce unresolved-type warnings; inspect and report them rather than calling a warning-producing run clean.
- The Node tests extract JavaScript from QML and mock native services. They cover logic, not QML bindings, rendering, focus, D-Bus delivery, or actual hardware behavior.
- Startup tests exercise the launcher with isolated Unix sockets and mocked system commands. For startup changes, validate the unit and both i3 and Hyprland session entries, and inspect the user-service journal.
- Inspect installed `.qmltypes` under `/usr/lib/qt6/qml/Quickshell/` and matching upstream source when API behavior is uncertain. Confirm units and lifecycle semantics rather than relying on names or documentation alone.
- Configs are symlinked and Quickshell reloads on edits. Check the current instance and its logs; do not launch a second full shell or run provisioning scripts just to validate a component.
- Confirm the reload log timestamp is newer than the edit before live-testing. Atomic file replacement may leave the running instance watching an old inode.
- For UI changes, exercise hover-to-panel traversal, pinning, Escape/outside closure, sibling-panel changes, rapid reversal, and list updates. Check light/dark appearance and relevant screen sizes; multi-monitor behavior needs explicit verification.
- For notifications, check arrivals during dismissal, burst expiry, hovered cards, Clear All snapshots, and reading position midway through and near the bottom of history.
- Do not toggle radios, switch networks, pair devices, clear real notification history, or change system settings merely to test without user approval. Use mocks or narrowly scoped synthetic data, and disclose what was not live-tested.
- Remove temporary IPC diagnostics, test notifications, and screenshots. Preserve unrelated worktree changes and never commit credentials, personal state, screenshots, or unresolved conflicts.
- Update this guide when an intentional design decision changes; keep it focused on current behavior and reusable guidance.
