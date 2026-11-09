-- Run: nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-watch.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local watch = require("core.lsp-watch")
local system = vim.system
local children, cancels = {}, {}
local base = vim.fn.tempname()
local root = base .. "/workspace[+] (test)"

local function wait(predicate, message)
  assert(vim.wait(5000, predicate, 10), message)
end

local function subscribe(path, opts, callback)
  local cancel = watch.watch(path, opts, callback)
  table.insert(cancels, cancel)
  return cancel
end

local function alive(process)
  return vim.uv.fs_stat("/proc/" .. process.pid) ~= nil
end

local function watch_count(process)
  local count = 0
  for _, file in ipairs(vim.fn.glob("/proc/" .. process.pid .. "/fdinfo/*", false, true)) do
    for _, line in ipairs(vim.fn.readfile(file)) do
      if line:match("^inotify wd:") then
        count = count + 1
      end
    end
  end
  return count
end

local function processes(command)
  return vim.tbl_filter(function(child) return child.command == command end, children)
end

local function write(path)
  vim.fn.writefile({ "content" }, path)
end

local ok, err = xpcall(function()
  assert(vim.fn.has("linux") == 1, "tests require Linux /proc")
  for _, command in ipairs({ "fd", "inotifywait" }) do
    assert(vim.fn.executable(command) == 1, command .. " is required")
  end
  vim.fn.mkdir(root .. "/src/attempt", "p")
  vim.fn.mkdir(root .. "/backend/tmp/deep", "p")
  vim.fn.mkdir(root .. "/src/tmp/deep", "p")
  vim.fn.mkdir(root .. "/.git/objects", "p")
  vim.system = function(command, ...)
    local process = system(command, ...)
    table.insert(children, { command = command[1], process = process })
    return process
  end
  watch.setup()
  assert(require("vim.lsp._watchfiles")._watchfunc == watch.watch)

  local all, filtered = {}, {}
  local cancel_all = subscribe(root, {}, function(path, kind) all[path] = kind end)
  local cancel_filtered = subscribe(root .. "/", {
    include_pattern = vim.glob.to_lpeg("**/*.lua"),
    exclude_pattern = vim.glob.to_lpeg("**/excluded.lua"),
  }, function(path, kind) filtered[path] = kind end)
  wait(function()
    local watchers = processes("inotifywait")
    return #watchers == 1 and watch_count(watchers[1].process) >= 4
  end, "shared watcher did not start")
  local process = processes("inotifywait")[1].process
  assert(#processes("fd") == 1, "duplicate directory discovery")
  assert(watch_count(process) == 4, "tmp/.git trees consumed watches")

  local source = root .. "/src/space and\nnewline.lua"
  local text = root .. "/src/attempt/keep.txt"
  local excluded = root .. "/src/excluded.lua"
  write(source)
  write(text)
  write(excluded)
  write(root .. "/backend/tmp/deep/ignored.lua")
  write(root .. "/src/tmp/deep/ignored.lua")
  wait(function() return filtered[source] and all[text] and all[excluded] end, "source events missing")
  assert(not filtered[text] and not filtered[excluded], "subscriber filters leaked")
  for path in pairs(all) do
    assert(not path:sub(#root + 2):match("^.-tmp/"), "tmp event leaked")
  end
  cancel_all()
  cancel_all()
  assert(alive(process), "unsubscribing stopped another subscriber's watcher")
  vim.fn.delete(source)
  wait(function() return filtered[source] == 3 end, "remaining subscriber lost delete event")
  assert(all[source] ~= 3, "cancelled subscriber received event")
  cancel_filtered()
  wait(function() return not alive(process) end, "last unsubscribe did not stop watcher")

  -- Cancellation before discovery's scheduled completion must not spawn a watcher.
  local discovery_done, killed
  vim.system = function(command, _, on_exit)
    assert(command[1] == "fd", "watcher spawned after cancellation")
    discovery_done = on_exit
    return { kill = function() killed = true end }
  end
  local cancel_early = subscribe(root, {}, function() error("cancelled callback") end)
  cancel_early()
  discovery_done({ code = 0, stdout = "", stderr = "" })
  local drained = false
  vim.schedule(function() drained = true end)
  wait(function() return drained end, "scheduled work did not drain")
  assert(killed, "discovery process was not stopped")
end, debug.traceback)

vim.system = system
for _, cancel in ipairs(cancels) do pcall(cancel) end
for _, child in ipairs(children) do
  if alive(child.process) then child.process:kill(2) end
end
vim.wait(3000, function()
  for _, child in ipairs(children) do
    if alive(child.process) then return false end
  end
  return true
end, 10)
vim.fn.delete(base, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end
print("PASS: relative exclusions, shared watcher, subscriber filters, filenames, cancellation")
