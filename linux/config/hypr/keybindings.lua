local SUPER = "SUPER"

-- Window Manager
hl.bind(SUPER .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(SUPER .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(SUPER .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(SUPER .. " + J", hl.dsp.focus({ direction = "d" }))

hl.bind(SUPER .. " + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind(SUPER .. " + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind(SUPER .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(SUPER .. " + DOWN", hl.dsp.focus({ direction = "d" }))

hl.bind(SUPER .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(SUPER .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(SUPER .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(SUPER .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

hl.bind(SUPER .. " + SHIFT + LEFT", hl.dsp.window.move({ direction = "l" }))
hl.bind(SUPER .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "r" }))
hl.bind(SUPER .. " + SHIFT + UP", hl.dsp.window.move({ direction = "u" }))
hl.bind(SUPER .. " + SHIFT + DOWN", hl.dsp.window.move({ direction = "d" }))

hl.bind(SUPER .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))

local digit = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
local ws = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

for i = 1, 10 do
  hl.bind(SUPER .. " + " .. digit[i], hl.dsp.focus({ workspace = ws[i] }))
  hl.bind(SUPER .. " + CTRL + " .. digit[i], hl.dsp.window.move({ workspace = ws[i], follow = false }))
  hl.bind(SUPER .. " + SHIFT + " .. digit[i], hl.dsp.window.move({ workspace = ws[i] }))
end

hl.bind(SUPER .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(SUPER .. " + SPACE", hl.dsp.exec_cmd("u_hypr-focus-mode-toggle"))

hl.bind(SUPER .. " + b", hl.dsp.focus({ workspace = "previous" }))
hl.bind(SUPER .. " + q", hl.dsp.window.close())
hl.bind(SUPER .. " + SHIFT + Q", hl.dsp.window.kill())

-- Layout setting
hl.bind(SUPER .. " + m", hl.dsp.layout("swapwithmaster master"))
hl.bind(SUPER .. " + e", hl.dsp.layout("orientationcycle"))
hl.bind(SUPER .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl keyword general:layout master"))
hl.bind(SUPER .. " + SHIFT + D", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"))

hl.bind(SUPER .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special" }))
hl.bind(SUPER .. " + minus", hl.dsp.workspace.toggle_special(""))

-- Submap for resizing windows
hl.bind(SUPER .. " + r", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
  hl.bind("right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
  hl.bind("left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = -15, relative = true }), { repeating = true })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = 15, relative = true }), { repeating = true })
  hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Mouse
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Applications
hl.bind(SUPER .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + CTRL + s", hl.dsp.exec_cmd('wf-recorder --geometry "$(slurp)"'))
hl.bind("SUPER + CTRL + p", hl.dsp.exec_cmd("1password --quick-access"))
hl.bind("SUPER + CTRL + f", hl.dsp.exec_cmd("kitty yazi"))
hl.bind("SUPER + CTRL + o", hl.dsp.exec_cmd("kitty oc"))
hl.bind("SUPER + CTRL + l", hl.dsp.exec_cmd("u_exit lock"))
hl.bind(SUPER .. " + d", hl.dsp.exec_cmd("tofi-drun --drun-launch=true"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("u_screenshot window"), { repeating = true })
hl.bind("SHIFT + CTRL + Print", hl.dsp.exec_cmd("u_screenshot output"), { repeating = true })
hl.bind("Print", hl.dsp.exec_cmd("u_screenshot region"), { repeating = true })
hl.bind("SUPER + CTRL + r", hl.dsp.exec_cmd("kooha"))
hl.bind("SUPER + CTRL + c", hl.dsp.exec_cmd('cliphist list | tofi --prompt-text="clip:" | cliphist decode | wl-copy'))

-- Volume and Media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("u_audio volume inc &"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("u_audio volume dec &"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("u_audio microphone toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("u_audio volume toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("u_music toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("u_music next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("u_music previous"), { locked = true })

-- System
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("u_backlight inc &"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("u_backlight dec &"), { locked = true, repeating = true })
