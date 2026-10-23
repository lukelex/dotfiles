# Quickshell design system

The existing shell is the visual reference: a quiet, compact monospace bar;
rounded translucent panels; opaque inset cards; Lucide line icons; neutral
controls with restrained blue selection. This system gives that appearance a
shared implementation and vocabulary.

## Sources of truth

| File | Responsibility |
| --- | --- |
| `DesignTokens.js` | Light/dark palettes, typography, shared geometry, density and basic motion |
| `Bar.qml` | Binds the palette to the current theme and exposes typed colors and typography through `controller` |
| `PanelSurface.qml` | Shared panel/OSD background, outline and corner radius |
| `SettingsSection.qml` | Settings card, subsection heading, divider and optional disclosure |
| `HeaderSettingsButton.qml` | Header settings action, tooltip, focus and optional destination menu |
| `LucideIcon.qml` | Shared SVG icon rendering |
| `AGENTS.md` | Interaction, accessibility, state and engineering requirements |

Import static tokens with `import "DesignTokens.js" as Design`. Read colors from
the supplied controller so theme changes remain reactive. Tokens use logical
pixels; motion uses milliseconds. Specialized layout and animation choreography
remain in their owning components. Do not promote every number into a token.

## Color

Colors retain the existing values. Qt's eight-digit notation is **#AARRGGBB**;
the base background has approximately 85% opacity.

| Controller token | Dark | Light | Meaning |
| --- | --- | --- | --- |
| `controlBackground` | `#D9171A20` | `#D9F8F9FB` | Panel and OSD base |
| `controlSurface` | `#2B303A` | `#E8EBEF` | Cards, notifications and inset surfaces |
| `controlBorder` | `#3A424E` | `#D8DDE4` | Panel outline |
| `controlSurfaceBorder` | `#33404D` | `#D7DCE3` | Card outlines and dividers |
| `controlPrimaryText` | `#F8F9FB` | `#20242A` | Main labels and values |
| `controlSecondaryText` | `#B7BEC9` | `#59616D` | Supporting text and intentional muted states |
| `controlHover` | `#38404C` | `#DCE1E8` | Ordinary neutral hover |
| `controlActive` | `#3E5978` | `#C9E1F7` | Selected/enabled background |
| `controlActiveIcon` | `#8CAED8` | `#5C94C8` | Active icon, focus and section identity |
| `controlSliderFill` | `#DDE1E7` | `#477AA8` | Level fill |
| `controlSliderTrack` | `#20242C` | `#D4D9E0` | Level track |
| `controlWarningText` | `#F0C674` | `#805500` | Actual warning |
| `controlDownloadIcon` | `#83E6B2` | `#167044` | Download direction, with a label/icon |
| `controlUploadIcon` | `#D6B4FF` | `#7442AD` | Upload direction, with a label/icon |

The bar also retains its fixed `foreground` (`#F3F4F5`), `muted` (`#A9ADB4`)
and `urgent` (`#DA4939`) colors. Use contextual control colors for panel text.
Muting and DND are intentional states, not errors. Important state differences
need text, icon or shape as well as color. Keep the existing dark scrim over
media artwork rather than relying on the panel palette for contrast there.

## Typography and icons

Use `controller.fontFamily` (`Hack Nerd Font Mono`) and the semantic size tokens:

| Token | Size | Use |
| --- | --- | --- |
| `Design.typography.metadata` | 10 | Timestamps and compact metadata |
| `Design.typography.caption` | 11 | Supporting text, tooltips, OSD values |
| `Design.typography.body` | 12 | Ordinary panel content, notification titles |
| `Design.typography.section` | 14 | Settings subsection headings, usually bold |
| `Design.typography.heading` | 16 | Panel headings |

The bar uses `controller.barFontSize`: 18 comfortable, 16 compact. Its height is
40 comfortable, 34 compact. Density currently changes those bar metrics; it
does not globally shrink panel text or hit targets.

Use `LucideIcon` and `controller.icon(name)`. Header icons are 16px; settings
section icons are 20px. Keep specialized bar and OSD icon sizes appropriate to
their existing layouts. Use plain text for untrusted labels; wrap meaningful
content and expose truncated values through tooltips or accessible descriptions.

## Spacing, shape and hierarchy

- Spacing vocabulary: `tight` 4, `small` 8, `related` 10, `row` 12,
  `card` 14, `section` 16.
- Panel recipe: 12px screen/bar gap, 16px inner padding, 26px radius and 1px
  outline. The standard narrow panel width is 432px, constrained to the screen.
  Task-specific panels can be wider.
- Settings card recipe: 18px radius, 14px padding, 10px icon/heading gap,
  12px body spacing and approximately 16px between sections.
- Control radius: 8px; menus: 10px; tooltips: 7px. Preserve existing specialized
  controls where their geometry differs rather than forcing everything into a
  single shape.
- Header action targets: 32px with 16px icons. The shared settings gear keeps
  its existing transparent resting background, surface-colored hover, 8px
  radius and 2px keyboard-focus outline. Other header actions can use their
  established neutral 10px-radius surface.
- Usage metrics use slim 6px tracks. OSD levels use their existing 8px tracks.
  Circular icon wells use half their diameter as the radius.

Group related content inside one surface and divide rows sparingly. Avoid
decorative gradients, redundant nested cards and large dashboard tiles without
a functional purpose.

## Surface recipes

### Bar and modules

Workspaces left, time/date centered, compact status and actions right. Each
permanent module must earn its space with frequent use or meaningful status.
Show detail and everyday actions in panels; send configuration to System
Settings. Module state comes from shared services, not parallel polling.

Hover previews do not steal focus. The bar stays non-focusable. Allow the
existing screen-local gap-crossing grace period; pinning enables deliberate
keyboard interaction. Opening a panel closes its siblings on that screen.

### Panels

Use `PanelSurface` for the base. Place the title and header actions above the
content; keep a continuous bounded scroll area for long content. Settings
access belongs in the header. Keep pending state and errors beside the action.
Pinned panels support Close, Escape and outside-click dismissal.

```qml
import QtQuick
import "DesignTokens.js" as Design

Item {
  id: view
  required property var controller

  PanelSurface {
    anchors.fill: parent
    controller: view.controller
  }

  Text {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: Design.panel.padding
    text: "Panel title"
    color: view.controller.controlPrimaryText
    font.family: view.controller.fontFamily
    font.pixelSize: Design.typography.heading
    textFormat: Text.PlainText
  }
}
```

`PanelSurface` owns only appearance. The parent still owns size, anchors,
focus, scrolling and lifecycle. It is used by the control, connectivity, audio,
today, review and notification panels, as well as system OSDs.

### Settings sections

Use `SettingsSection` rather than recreating subsection cards. Supply
`controller`, `title` and `iconName`; place the controls in its default contents.
Keep labels and compact editors inline when they fit, stacking at narrow widths.
Use disclosure only for secondary material. Preserve focus and scroll position.

### Notifications

Toast width is at most 396px with 12px screen clearance. The extra animation
margin is not part of the card width. Cards use `controlSurface`, a
`controlSurfaceBorder` outline and 18px corners. Preserve the current hierarchy:
10px metadata, 12px title, 11px body/actions, plus app icon or image.

History lives inside a standard panel and retains its existing grouped-card
layout. Toasts and history share the palette and visual vocabulary while owning
their different grouping, expansion and dismissal behavior. Preserve hover
protection and sender deadlines. Sound, history and native delivery lifecycle
are separate from presentation; DND does not suppress system OSDs.

### System OSDs

Use the panel base with the existing centered 216 × 172px recipe, 64px below the
bar, 22px padding, 66px icon well, 34px icon and 8px level track. Use an 11px
secondary-text value or label. Muted state uses a muted icon and explicit label.
Layout, reload and monitor messages use the labeled variant instead of a meter.

## Motion and state

Panel/OSD entry uses `Design.motion.enter` (160ms), usually OutCubic; exit uses
`Design.motion.exit` (120ms), usually InCubic. Settings tooltips wait 500ms.
Keep animation cancellation and reversal in the owning component.

Notification motion is a separate recipe: current toast entry is 280ms,
dismissal translation 240ms with 180ms fade; history dismissal uses 260ms
translation and 200ms fade. Group expansion and finite urgent emphasis retain
their local choreography. Do not replace these with panel timing or add looping
attention cues, spring overshoot or motion unrelated to a state transition.

Always distinguish enabled, disabled, disconnected, unavailable and pending.
Confirm success from backend state; preserve the user's selection on failure.
Use keyboard focus outlines, accessible action names and non-overlapping hit
areas. Hover must not be the only way to access essential information/actions.

## Extending and checking the system

1. Reuse a semantic color and existing component before adding a variant.
2. Add a token when a value is a shared design decision or a named surface
   recipe. Keep one-off geometry and behavior local.
3. Preserve the current look when refactoring: a changed token is an intentional
   visual change across all consumers. Update this document with that decision.
4. Check light/dark, comfortable/compact, narrow layouts and long labels. Check
   both i3/X11 and Hyprland/Wayland, multi-monitor placement, focus, Escape,
   hover-to-pin handoff and rapid animation reversal when relevant.
5. Run the checks in `AGENTS.md`. QML lint and Node tests do not validate visual
   rendering; inspect the existing shell after its live reload.

Adoption is deliberate: colors and bar density are centralized for all existing
controller consumers; panel bases, key headings, shared settings controls,
OSD geometry and toast geometry use the shared primitives/tokens. Specialized
rows, media layouts and notification choreography still contain local values.
