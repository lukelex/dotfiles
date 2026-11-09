-- Run: nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-watch.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local watch = require("core.lsp-watch")
local system = vim.system
local notify = vim.notify
local errors = {}
vim.notify = function(message) table.insert(errors, message) end
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
    local readable, lines = pcall(vim.fn.readfile, file)
    for _, line in ipairs(readable and lines or {}) do
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

  -- Hold a rebuild's discovery result: the old watcher must keep delivering
  -- source events until its replacement is ready.
  local spawn = vim.system
  local finish_discovery
  vim.system = function(command, options, on_exit)
    if command[1] == "fd" then
      return spawn(command, options, function(result)
        finish_discovery = function() on_exit(result) end
      end)
    end
    return spawn(command, options, on_exit)
  end
  vim.fn.mkdir(root .. "/tmp/new/deep", "p")
  write(root .. "/tmp/new/deep/ignored.lua")
  wait(function() return finish_discovery ~= nil end, "new tmp did not trigger rediscovery")
  local during = root .. "/src/during-rebuild.lua"
  write(during)
  wait(function() return filtered[during] ~= nil end, "old watcher stopped before replacement was ready")
  vim.system = spawn
  finish_discovery()
  local function handoff(previous, count)
    local current
    wait(function()
      local live = vim.tbl_filter(function(child) return alive(child.process) end, processes("inotifywait"))
      if not alive(previous) and #live == 1 and watch_count(live[1].process) == count then
        current = live[1].process
        return true
      end
      return false
    end, "watcher handoff did not prune tmp directories")
    return current
  end
  process = handoff(process, 4)
  for path in pairs(all) do
    local relative = "/" .. path:sub(#root + 2) .. "/"
    assert(not relative:find("/tmp/", 1, true), "dynamic tmp event leaked")
  end

  -- Moving in a normal directory may introduce already-populated tmp subtrees.
  vim.fn.mkdir(base .. "/staging/src", "p")
  vim.fn.mkdir(base .. "/staging/tmp/deep", "p")
  write(base .. "/staging/tmp/deep/ignored.lua")
  assert(vim.uv.fs_rename(base .. "/staging", root .. "/imported"))
  process = handoff(process, 6)
  local imported = root .. "/imported/src/keep.lua"
  write(imported)
  wait(function() return filtered[imported] ~= nil end, "moved-in source directory is not watched")

  -- Ordinary new directories should not replace the watcher when exclusions
  -- stay the same; inotifywait already adds those watches itself.
  local discoveries_finished = false
  local generations = #processes("inotifywait")
  vim.system = function(command, options, on_exit)
    if command[1] == "fd" then
      return spawn(command, options, function(result)
        on_exit(result)
        vim.schedule(function() discoveries_finished = true end)
      end)
    end
    return spawn(command, options, on_exit)
  end
  vim.fn.mkdir(root .. "/src/normal", "p")
  wait(function() return discoveries_finished end, "normal directory discovery did not finish")
  vim.system = spawn
  assert(#processes("inotifywait") == generations, "unchanged exclusions replaced the watcher")
  local normal = root .. "/src/normal/keep.lua"
  write(normal)
  wait(function() return filtered[normal] ~= nil end, "normal new directory is not watched")

  cancel_all()
  cancel_all()
  assert(alive(process), "unsubscribing stopped another subscriber's watcher")
  vim.fn.delete(source)
  wait(function() return filtered[source] == 3 end, "remaining subscriber lost delete event")
  assert(all[source] ~= 3, "cancelled subscriber received event")

  -- Cancellation during handoff must kill both generations, even if a readiness
  -- callback arrives after cancellation.
  local held_stderr
  vim.system = function(command, options, on_exit)
    if command[1] == "inotifywait" then
      local stderr = options.stderr
      options.stderr = function(error, data)
        if data then held_stderr = function() stderr(error, data) end end
      end
    end
    return spawn(command, options, on_exit)
  end
  vim.fn.mkdir(root .. "/src/new-dir/tmp", "p")
  wait(function()
    return held_stderr and #vim.tbl_filter(function(child)
      return alive(child.process)
    end, processes("inotifywait")) == 2
  end, "replacement did not start")
  cancel_filtered()
  held_stderr()
  vim.system = spawn
  wait(function()
    for _, child in ipairs(processes("inotifywait")) do
      if alive(child.process) then return false end
    end
    return true
  end, "last unsubscribe did not stop both watcher generations")

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
  assert(#errors == 0, "unexpected watcher errors: " .. table.concat(errors, "; "))
end, debug.traceback)

vim.system = system
vim.notify = notify
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
print("PASS: relative exclusions, shared watcher, filters, filenames, dynamic tmp pruning, handoff, cancellation")
