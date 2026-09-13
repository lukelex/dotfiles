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
- Keep system OSDs distinct from notification history. Release references when native notifications close; do not invoke methods on destroyed objects.
- Respect explicit persistent timeouts. The installed Quickshell 0.3.1 build was live-verified to expose notification timeouts in milliseconds despite conflicting documentation; verify units again when changing versions.

## Architecture And Platform

- `shell.qml` composes the shell. `Bar.qml` owns shared visual tokens and per-screen panel wiring.
- `*Center.qml` files own panel presentation and interaction. `NotificationService.qml` and `ConnectivityService.qml` own backend state and lifecycle; do not duplicate their state through independent polling in a panel.
- Prefer native, event-driven Quickshell modules when available. Connectivity uses `Quickshell.Networking` over NetworkManager and `Quickshell.Bluetooth` over BlueZ. Do not bypass NetworkManager by controlling its iwd backend directly.
- Activate saved Wi-Fi profiles without an explicit disconnect first. Keep available saved networks active-first, then in stable name/device order, not constantly changing signal-strength order.
- Enable Wi-Fi scanning only while the connectivity panel is open. Do not continuously discover Bluetooth devices just to show connected-device batteries.
- Bluetooth battery and native Wi-Fi strength values are fractions (0-1). Check `batteryAvailable`; unavailable battery data is not 0%.
- Delegate advanced networking and pairing to `nm-connection-editor` and `blueman-manager`. Release popup grabs before opening another application.
- On Quickshell 0.3.1/X11, `PopupWindow.grabFocus` alone does not reliably implement keyboard/pointer grabs. `ConnectivityCenter.qml` uses a non-grabbing hover preview and `Controls.Popup.Window` for the pinned view, sharing one content item. Preserve this distinction unless a replacement is live-verified.
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
- Inspect installed `.qmltypes` under `/usr/lib/qt6/qml/Quickshell/` and matching upstream source when API behavior is uncertain. Confirm units and lifecycle semantics rather than relying on names or documentation alone.
- Configs are symlinked and Quickshell reloads on edits. Check the current instance and its logs; do not launch a second full shell or run provisioning scripts just to validate a component.
- For UI changes, exercise hover-to-panel traversal, pinning, Escape/outside closure, sibling-panel changes, rapid reversal, and list updates. Check light/dark appearance and relevant screen sizes; multi-monitor behavior needs explicit verification.
- For notifications, check arrivals during dismissal, burst expiry, hovered cards, Clear All snapshots, and reading position midway through and near the bottom of history.
- Do not toggle radios, switch networks, pair devices, clear real notification history, or change system settings merely to test without user approval. Use mocks or narrowly scoped synthetic data, and disclose what was not live-tested.
- Remove temporary IPC diagnostics, test notifications, and screenshots. Preserve unrelated worktree changes and never commit credentials, personal state, screenshots, or unresolved conflicts.
- Update this guide when an intentional design decision changes; do not turn it into a session log or freeze incidental implementation details as permanent requirements.
