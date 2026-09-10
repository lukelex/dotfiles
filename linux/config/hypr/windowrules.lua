-- For screensharing. See https://wiki.hyprland.org/Useful-Utilities/Screen-Sharing/#xwayland
hl.window_rule({
  match = {
    class = "^(xwaylandvideobridge)$",
  },
  opacity = "0.0 override",
  no_anim = true,
  no_initial_focus = true,
  max_size = { 1, 1 },
  no_blur = true,
})