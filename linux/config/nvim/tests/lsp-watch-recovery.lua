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
local function tick(delay)
  local selected
  for index, timer in ipairs(timers) do
    if not timer.closed and (not delay or timer.delay == delay)
      and (not selected or timer.delay < timers[selected].delay) then
      selected = index
    end
  end
  local timer = selected and table.remove(timers, selected)
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
  recovered.options.stdout(nil, "/test/workspace/incoming\0CREATE,ISDIR\0")
  drain()
  tick()
  local replacement = discovered("/test/workspace/incoming/tmp\0")
  replacement.done({ code = 1 })
  drain()
  assert(not recovered.killed, "failed replacement killed healthy watcher")
  assert(tick() == 1000)
  replacement = discovered("/test/workspace/incoming/tmp\0")
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
  assert(not vim.iter(timers):any(function(timer) return not timer.closed end), "retry loop was not bounded")
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
  local retry_timer = timers[#timers]
  cancel()
  retry_timer.callback()
  assert(#jobs == 0, "cancelled recovery spawned a process")

  -- A living process that never completes must consume the same retry budget.
  timers, jobs = {}, {}
  cancel = subscribe()
  local hung_discovery = jobs[#jobs]
  assert(tick(30000) == 30000)
  assert(hung_discovery.killed, "hung discovery was not killed")
  assert(tick() == 250)
  local next_discovery = jobs[#jobs]
  hung_discovery.done({ code = 0, stdout = "", stderr = "" })
  drain()
  assert(jobs[#jobs] == next_discovery, "late discovery spawned a stale watcher")
  local healthy = discovered()
  ready(healthy)
  healthy.options.stdout(nil, "/test/workspace/tmp\0CREATE,ISDIR\0")
  drain()
  tick(100)
  local hung_replacement = jobs[#jobs]
  assert(hung_replacement.command[1] == "inotifywait")
  tick(30000)
  assert(hung_replacement.killed and not healthy.killed, "deadline interrupted healthy active watcher")
  ready(hung_replacement)
  assert(not healthy.killed, "late readiness retired the healthy watcher")
  assert(tick() == 1000)
  local resumed = discovered("/test/workspace/tmp\0")
  ready(resumed)
  assert(healthy.killed, "recovered replacement did not take over")
  cancel()

  timers, jobs = {}, {}
  cancel = subscribe()
  local deadline = timers[#timers]
  local stopped = jobs[#jobs]
  cancel()
  deadline.callback()
  stopped.done({ code = 0, stdout = "", stderr = "" })
  drain()
  assert(#jobs == 1, "cancelled deadline restarted discovery")
end, debug.traceback)
for _, cancel in ipairs(cancels) do pcall(cancel) end
vim.system, vim.defer_fn, vim.notify = system, defer, notify
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
print("PASS: watcher recovery, healthy handoff, bounded retries, spawn/discovery failure, cancellation")
