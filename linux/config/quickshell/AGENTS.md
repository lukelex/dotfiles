# Quickshell Design And Engineering Guide

Use alongside the root `AGENTS.md`. This shell supports both i3/X11 and
Hyprland/Wayland; platform-specific behavior must be verified independently.

## Design Principles

- Keep the bar a quiet status surface: workspaces left, time/date centered, compact status/actions right. Permanent elements must earn their space through frequent use or meaningful status.
- Put detail and everyday actions in panels, configuration in the shared System Settings window, and unsupported advanced workflows in existing native tools. Keep one UI and one source of state per capability.
- Lead with an overview and common actions. Disclose advanced controls progressively; avoid extra tabs or clicks for the primary task. Preserve existing shortcuts and contextual destinations.
- Separate navigation, preferences, drafts and explicit actions. Opening a page or changing a presentation preference must not silently perform an unrelated system action.
- Show only supported controls for the active session. Omit empty groups; distinguish unavailable, disabled, disconnected and pending states. Never substitute fabricated values for missing observations.
- Prefer the smallest correct change. Reuse components when there is actual reuse; avoid speculative settings, abstractions and compatibility layers.

## Visual Language

- Use `DESIGN.md` for the design system and component recipes. `DesignTokens.js` owns palettes and shared metrics; `Bar.qml` exposes reactive theme colors and typography through the controller. Use `PanelSurface.qml` for panel/OSD bases and the shared settings components for their existing roles.
- Reuse the controller's theme colors and typography and import static metrics from `DesignTokens.js` as `Design`. Support light/dark themes and existing comfortable/compact sizing; do not introduce competing fonts or bar icon scales.
- Use `LucideIcon.qml` with assets from `../lucide/svg/`. Verify assets exist and preserve their license when adding variants.
- Use `controlBackground` for the base, `controlSurface` for cards, `controlBorder` for panel outlines, and `controlSurfaceBorder` for card outlines/dividers. Use `controlPrimaryText` and `controlSecondaryText` for hierarchy.
- Ordinary hover uses neutral `controlHover`. Restrained blue indicates selection/enabled state; warning colors indicate genuine problems. Muting and DND are intentional states, not warnings. Never convey important distinctions through color alone.
- Panels sit about 12px below the bar with roughly 16px padding and rounded surfaces. Constrain them to screen bounds; allow wider content only when its task requires it.
- Panel headings are 16px. Header gear/close controls use 32px targets and 16px icons; retain the shared gear's 8px radius and other header controls' 10px-radius neutral surfaces. Place settings access in the header, with a contextual tooltip, rather than a large footer action.
- Keep labels legible and controls usable at narrow widths. Wrap meaningful text, reveal truncated values on hover/focus, and provide specific accessible names. Avoid overlapping hit areas.
- Use slim 6px tracks for usage metrics. Keep normal values neutral and label units, direction and unavailable states honestly. Preserve contrast over media artwork with the existing dark scrim.
- Avoid decorative gradients, oversized headings, constant motion, redundant borders and dashboard tiles without a functional purpose.

## System Settings Pattern

- Use the shared resizable window, preserving its `Quickshell System Settings` title for window-manager rules. Close/Escape dismisses it. Generic requests open System information; explicit requests keep their destination.
- Keep the page title and icon-and-label sidebar fixed. Collapse the sidebar to icons with tooltips at narrow widths, and let it scroll when necessary.
- Use one continuous scroll area per page, including application/device lists and global controls. Stop at scroll bounds without overscroll bounce.
- Use `SettingsSection.qml` for subsections: an 18px-radius surface card, 14px inner padding, and approximately 16px between cards. The header pairs a 20px Lucide icon in `controlActiveIcon` with a bold 14px primary-text label, spaced 10px apart. Header color identifies a group; it does not imply an enabled setting.
- Enclose the subsection's controls, rows and empty/error states inside the same card. Separate related rows with thin dividers rather than independent nested cards. Keep related enable/threshold or label/value controls together.
- Place compact inputs inline with their labels when their measured content fits the available width; right-align the editor. Stack label and editor at narrower widths or for long values, retaining the same control and focus. Size choices for their longest option rather than only the current selection.
- Preserve useful disclosure behavior. Collapsible card headers use a trailing chevron, wrap at narrow widths, and retain the reader's position when toggled. Do not hide primary actions behind new disclosures merely to shorten a page.
- Reuse metadata-driven preference controls and backend validation. Filter fields by session before building cards and omit groups with no applicable fields.
- Put live summaries alongside the controls they describe. Read applied backend state rather than editable drafts; observations and runtime identifiers are not portable preferences.

## Interaction And Motion

- Hover previews never steal focus. Allow a short screen-local gap-crossing grace period and cancel delayed closure on re-entry. Pinning enables deliberate keyboard interaction; pinned panels support Close, Escape and outside-click dismissal, not hover exit.
- Keep the bar non-focusable. Route shortcuts, actions and timers to the actual screen's panel. Opening one panel closes siblings and cancels stale requests; release popup grabs before opening settings or external tools.
- Preserve the visual handoff when promoting a preview to a pinned window, retaining its snapshot until the destination renders. Ordinary settings windows follow normal window-manager focus rules.
- Show pending state immediately, reject competing duplicate actions, and report success only after backend confirmation. Put errors beside the attempted action; keep user selections through refreshes.
- Reconcile dynamic lists by stable identity. Preserve surviving delegates, focus, expanded details and reading position; avoid reordering under the pointer. Anchor scroll compensation to a surviving row, clamp to bounds, and never fight manual scrolling.
- Animate transitions, not decoration: roughly 160/120ms panel entry/exit and 180–260ms notification dismissal. No spring overshoot or looping attention cues. Cancel opposing animations during rapid reversals.
- Capture action targets before asynchronous work or dismissal. New arrivals must not change the affected set. Keep departing visuals alive through their exit, then reconcile state; batch bursts instead of building animation backlogs.

## State And Backend Contracts

- `shell.qml` composes the shell; `DesignTokens.js` owns shared visual values; `Bar.qml` binds them to preferences and owns per-screen wiring. Presentation components consume shared services rather than duplicating backend state or polling.
- Prefer native event-driven Quickshell services. Bound subprocesses with timeouts, validate payloads and object identity, and ignore stale responses. Coalesce slider edits against captured targets; never retarget queued work to replacement devices.
- Run scans, metering and frequent sampling only while their relevant surface or explicit policy needs them. Use debouncing, cooldowns and expiry-based refreshes; unrelated panels must not activate each other's work.
- Treat freshness, measurements and capabilities honestly. Check native units and availability flags; distinguish advertised limits from negotiated state, estimates from measurements, and device links from internet access. Privacy indicators must observe activity without starting capture.
- `../system-settings/preferences.json` is authoritative and tracked. `SystemPreferences.qml` uses validated, locked, atomic helper writes; UI edits intentionally dirty the repo. Local settings are mirrors. Keep history, secrets, live IDs and transient overrides outside portable preferences. See `../system-settings/README.md`.
- Monitor layouts use `monitor-profiles.json` and a draft/apply/confirm workflow. Preserve the independent rollback guard, verify actual state before Keep, and save only confirmed layouts. Never bypass recovery to simplify UI.
- Preserve authentication and lock-before-suspend. Presentation failures must not prevent locking. Keep credentials out of shell arguments, logs and preferences; use the supported native credential APIs.
- Keep notification presentation, sound, history and native lifecycle distinct. DND or mute must not destroy history, replay suppressed records, or affect independent system OSDs. Respect app policy, sender deadlines and hover protection; never persist transient image URLs or invoke destroyed native objects.
- Notification history keys are durable and separate from reusable native delivery IDs. Keep their mapping runtime-only; migrate saved history and seen-state keys consistently without binding restored records to new native deliveries.
- Keep helpers self-contained beside the config and invoke them by absolute path. Both sessions use `scripts/quickshell --session-start` and the shared user service; import only the active session's environment and do not enable the service on `default.target`.
- Read the relevant service, helper and tests before changing behavior. Keep detailed protocol rules, field definitions and feature-specific invariants there rather than expanding this guide into a feature inventory.

## Validation

Run appropriate checks from the repository root:

```sh
node --test linux/config/quickshell/tests/*.test.cjs
/usr/lib/qt6/bin/qmllint linux/config/quickshell/<changed-file>.qml
git diff --check -- linux/config/quickshell linux/config/lucide
quickshell list --all
quickshell log --pid <current-pid> --tail 30
```

- Lint every changed QML file with Qt 6. Inspect and report native-type metadata warnings rather than calling a warning-producing run clean. Consult installed `.qmltypes` and matching upstream source when API semantics are uncertain.
- Node tests mock native services and cover logic, not rendering, focus, D-Bus or hardware. Test normal/narrow layouts, light/dark themes, relevant sessions and multi-monitor behavior as applicable. Exercise disclosures, hover/pin transitions, Escape, rapid reversal and list updates.
- Configs are symlinked and reload live. Inspect the existing instance and confirm a reload newer than the edit; atomic replacement can leave a stale watcher. Do not launch another full shell or run provisioning merely to test a component.
- Use isolated fixtures for backend tests. Do not change real layouts, radios, routes, audio levels, settings or notification history merely to validate UI without approval. Disclose what was not live-tested.
- Remove temporary diagnostics, synthetic notifications and screenshots. Preserve unrelated work and never commit credentials, personal runtime state or unresolved conflicts. Update this guide only for reusable design or engineering decisions.
