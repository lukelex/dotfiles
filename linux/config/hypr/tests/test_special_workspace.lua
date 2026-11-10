local function dispatcher(path)
  return setmetatable({}, {
    __index = function(_, key)
      return dispatcher(path .. "." .. key)
    end,
    __call = function(_, ...)
      return { action = path, args = { ... } }
    end,
  })
end

local bindings = {}
local regular = { id = 1, addressable_name = "1" }
local special = { addressable_name = "special" } -- special workspaces have no Lua id
local visible = false
local active_window
local focused_window

hl = {
  dsp = dispatcher(""),
  bind = function(key, action)
    bindings[key] = action
  end,
  define_submap = function() end,
  get_active_special_workspace = function()
    return visible and special or nil
  end,
  get_active_workspace = function()
    return regular
  end,
  get_active_window = function()
    return active_window
  end,
  dispatch = function(action)
    if action.action == ".workspace.toggle_special" then
      visible = not visible
    elseif action.action == ".focus" then
      focused_window = action.args[1].window
    end
  end,
}

dofile("linux/config/hypr/keybindings.lua")
local toggle = bindings["SUPER + minus"]
assert(type(toggle) == "function")

local regular_window = { workspace = regular, mapped = true, hidden = false }
local special_window = { workspace = special, mapped = true, hidden = false }

active_window = regular_window
toggle() -- opening the special workspace saves the normal window
assert(visible)

active_window = special_window
toggle() -- closing it saves the special window and restores normal focus
assert(not visible)
assert(focused_window == regular_window)

focused_window = nil
active_window = regular_window
toggle() -- reopening restores special focus, despite its nil id
assert(visible)
assert(focused_window == special_window)

active_window = special_window
toggle()
special_window.workspace = regular -- do not focus a window that moved away
focused_window = nil
active_window = regular_window
toggle()
assert(focused_window == nil)

active_window = nil
toggle()
special_window.workspace = special
special_window.mapped = false -- do not focus a closed window
focused_window = nil
toggle()
assert(focused_window == nil)
