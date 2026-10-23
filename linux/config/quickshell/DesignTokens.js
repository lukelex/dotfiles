.pragma library

// The current shell's visual contract. QML consumers import this as Design.
// Keep component-specific geometry local unless it is shared or a named recipe.
var typography = Object.freeze({
  family: "Hack Nerd Font Mono",
  metadata: 10,
  caption: 11,
  body: 12,
  section: 14,
  heading: 16
})

var radius = Object.freeze({ tooltip: 7, control: 8, menu: 10, card: 18, panel: 26 })
var spacing = Object.freeze({ tight: 4, small: 8, related: 10, row: 12, card: 14, section: 16 })
var stroke = Object.freeze({ outline: 1, focus: 2 })
var icon = Object.freeze({ header: 16, section: 20 })
var panel = Object.freeze({ gap: 12, padding: 16, headerHeight: 32, width: 432 })
var notification = Object.freeze({ width: 396, radius: 18 })
var osd = Object.freeze({ width: 216, height: 172, offset: 64, padding: 22, iconWell: 66, icon: 34, track: 8 })
var motion = Object.freeze({ enter: 160, exit: 120, tooltipDelay: 500 })

function barMetrics(compact) {
  return { height: compact ? 34 : 40, fontSize: compact ? 16 : 18 }
}

// Alpha is Qt's #AARRGGBB. Background deliberately retains its current translucency.
function palette(dark) {
  return {
    foreground: "#F3F4F5",
    urgent: "#DA4939",
    muted: "#A9ADB4",
    controlActive: dark ? "#3E5978" : "#C9E1F7",
    controlActiveIcon: dark ? "#8CAED8" : "#5C94C8",
    controlDownloadIcon: dark ? "#83E6B2" : "#167044",
    controlUploadIcon: dark ? "#D6B4FF" : "#7442AD",
    controlWarningText: dark ? "#F0C674" : "#805500",
    controlBackground: dark ? "#D9171A20" : "#D9F8F9FB",
    controlPrimaryText: dark ? "#F8F9FB" : "#20242A",
    controlSecondaryText: dark ? "#B7BEC9" : "#59616D",
    controlSliderFill: dark ? "#DDE1E7" : "#477AA8",
    controlSliderTrack: dark ? "#20242C" : "#D4D9E0",
    controlSurface: dark ? "#2B303A" : "#E8EBEF",
    controlBorder: dark ? "#3A424E" : "#D8DDE4",
    controlSurfaceBorder: dark ? "#33404D" : "#D7DCE3",
    controlHover: dark ? "#38404C" : "#DCE1E8"
  }
}
