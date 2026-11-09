-- Deterministic process/timer fault injection; no plugins or external processes.
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local system, defer, notify = vim.system, vim.defer_fn, vim.notify
local jobs, timers, messages = {}, {}, {}
local throw_command
vim.system = function(command, options, done)
  if command[1] == throw_command then error("injected spawn failure") end
  local job = { command = command, options = options, done = done }
  job.kill = function() job.killed = true end
  table.insert(jobs, job)
  return job
end
vim.defer_fn = function(callback, delay)
  local timer = { callback = callback, delay = delay }
  timer.stop = function() timer.closed = true end
  timer.close = timer.stop
  timer.is_closing = function() return timer.closed or false end
  table.insert(timers, timer)
  return timer
end
vim.notify = function(message) table.insert(messages, message) end
local function drain()
  local done = false
  vim.schedule(function() vim.schedule(function() done = true end) end)
  assert(vim.wait(1000, function() return done end, 1))
end
local function tick()
  local timer = table.remove(timers, 1)
  assert(timer, "missing retry timer")
  if not timer.closed then timer.closed = true; timer.callback() end
  drain()
  return timer.delay
end
local function discovered(output)
  jobs[#jobs].done({ code = 0, stdout = output or "", stderr = "" })
  drain()
  return jobs[#jobs]
end
local function ready(job)
  job.options.stderr(nil, "Watches established.\n")
  drain()
end
local cancels = {}
local function subscribe()
  local cancel = require("core.lsp-watch").watch("/test/workspace", {}, function() end)
  table.insert(cancels, cancel)
  return cancel
end
local ok, err = xpcall(function()
  local cancel = subscribe()
  local active = discovered()
  ready(active)
  active.done({ code = 9 })
  drain()
  assert(tick() == 250)
  local recovered = discovered()
  ready(recovered)
  assert(active.killed and recovered ~= active, "dead watcher not replaced")

  -- A failed replacement must not interrupt the healthy active generation.
  recovered.options.stdout(nil, "/test/workspace/tmp\0CREATE,ISDIR\0")
  drain()
  tick()
  local replacement = discovered("/test/workspace/tmp\0")
  replacement.done({ code = 1 })
  drain()
  assert(not recovered.killed, "failed replacement killed healthy watcher")
  assert(tick() == 1000)
  replacement = discovered("/test/workspace/tmp\0")
  ready(replacement)
  assert(recovered.killed, "successful recovery did not retire old watcher")
  cancel()
  assert(replacement.killed)

  -- Readiness alone must not reset the budget for a rapidly crashing process.
  timers, jobs, messages = {}, {}, {}
  cancel = subscribe()
  for attempt = 1, 4 do
    local job = discovered()
    ready(job)
    job.done({ code = 1 })
    drain()
    if attempt < 4 then assert(tick() == ({ 250, 1000, 4000 })[attempt]) end
  end
  assert(#timers == 0, "retry loop was not bounded")
  assert(messages[#messages]:find("recovery exhausted", 1, true))
  cancel()

  -- Discovery failures and synchronous spawn errors use the same bounded path.
  timers, jobs = {}, {}
  cancel = subscribe()
  jobs[#jobs].done({ code = 1, stdout = "", stderr = "injected fd failure" })
  drain()
  assert(tick() == 250)
  throw_command = "inotifywait"
  discovered()
  assert(tick() == 1000)
  throw_command = nil
  local job = discovered()
  ready(job)
  cancel()

  timers, jobs = {}, {}
  throw_command = "fd"
  cancel = subscribe()
  throw_command = nil
  cancel()
  tick()
  assert(#jobs == 0, "cancelled recovery spawned a process")
end, debug.traceback)
for _, cancel in ipairs(cancels) do pcall(cancel) end
vim.system, vim.defer_fn, vim.notify = system, defer, notify
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
print("PASS: watcher recovery, healthy handoff, bounded retries, spawn/discovery failure, cancellation")
