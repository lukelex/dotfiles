require("workspaces")
require("windowrules")
require("keybindings")

hl.env("EDITOR", "nvim")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")
hl.env("KITTY_CONFIG_DIRECTORY", os.getenv("HOME") .. "/dotfiles/linux/config/kitty")

hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("HYPRCURSOR_SIZE", "28")

hl.monitor({
  output = "",
  mode = "highres",
  position = "auto",
  scale = 1,
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

hl.config({
  input = {
    kb_layout = "us",
    repeat_rate = 35,
    repeat_delay = 300,
    follow_mouse = 2,
    sensitivity = 0.6,
    accel_profile = "flat",
    natural_scroll = true,
    mouse_refocus = false,
    float_switch_override_focus = 0,
    special_fallthrough = true,
    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,
      clickfinger_behavior = true,
      tap_to_click = true,
      drag_lock = false,
    },
  },
  binds = {
    workspace_center_on = 1,
    allow_workspace_cycles = true,
  },
  general = {
    layout = "master",
    allow_tearing = false,
    gaps_in = 12,
    gaps_out = 12,
    border_size = 6,
    ["col.active_border"] = "0xffcc7833",
    ["col.inactive_border"] = "0xff2b2b2b",
    resize_on_border = true,
    hover_icon_on_border = true,
    no_focus_fallback = true,
  },
  cursor = {
    no_warps = true,
    enable_hyprcursor = true,
    hide_on_key_press = false,
    hide_on_touch = true,
  },
  decoration = {
    rounding = 6,
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    force_split = 2,
    default_split_ratio = 1.0,
  },
  master = {
    mfact = 0.5,
    orientation = "center",
    new_status = "slave",
    allow_small_split = true,
    drop_at_cursor = true,
  },
  misc = {
    focus_on_activate = true,
    on_focus_under_fullscreen = 2,
    disable_autoreload = false,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    mouse_move_enables_dpms = true,
    vrr = 3,
  },
})

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "default", style = "popin" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "default", style = "fade" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "default", style = "fade" })

hl.on("hyprland.start", function()
  hl.exec_cmd('"$HOME/dotfiles/linux/theming"')
  hl.exec_cmd('play "$HOME/dotfiles/sounds/desktop-login.oga" &> /dev/null &')
  hl.exec_cmd('"$HOME/dotfiles/linux/config/autostart"')
  hl.exec_cmd("xwaylandvideobridge")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Disable X related services
-- hl.exec_cmd("$HOME/dotfiles/linux/scripts/disable-x-services")