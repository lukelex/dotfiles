local M = {}
local roots = {}
local restarting = {}

local function overlaps(a, b)
  a, b = a:gsub("/$", ""), b:gsub("/$", "")
  return a == b or vim.startswith(a, b .. "/") or vim.startswith(b, a .. "/")
end

local function resync_clients(path)
  -- LSP has no portable full-workspace invalidation request. After lost coverage,
  -- reinitialize overlapping clients so deleted/changed unopened files are reread.
  for _, client in ipairs(vim.lsp.get_clients()) do
    local affected = client.config.root_dir and overlaps(path, client.config.root_dir)
    for _, folder in ipairs(client.workspace_folders or {}) do
      affected = affected or overlaps(path, vim.uri_to_fname(folder.uri))
    end
    if affected and not restarting[client.id] then
      restarting[client.id] = true
      vim.schedule(function()
        restarting[client.id] = nil
        if client:is_stopped() then return end
        local buffers = vim.tbl_keys(client.attached_buffers)
        local config = vim.deepcopy(client.config)
        client:stop(true)
        local ok, id = pcall(vim.lsp.start, config, {
          attach = false,
          reuse_client = function() return false end,
        })
        if not ok or not id then
          vim.notify("LSP watcher recovered but could not restart " .. client.name, vim.log.levels.ERROR)
          return
        end
        for _, buf in ipairs(buffers) do
          if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            -- didOpen sends the live buffer, including unsaved edits.
            vim.lsp.buf_attach_client(buf, id)
          end
        end
      end)
    end
  end
end

local function regex_escape(value)
  return (value:gsub("[\\%^%$%.%|%?%*%+%(%)%[%]%{%}]", "\\%0"))
end

-- Neovim's built-in inotify backend filters events only after recursively
-- installing watches. Exclude tmp trees in inotifywait itself instead.
local function start(path, callback)
  local cancelled = false
  local active, replacement, discovery, timer
  local dirty = false
  local changed_dirs, cached_exclusions = {}, nil
  local failures, recovering, exhausted = 0, false, false
  local lost_coverage = false
  local total_retries = 0
  local last_error, last_error_at
  local retry_delays = { 250, 1000, 4000 }
  local refresh
  local prefix = path:gsub("/$", "") .. "/"
  local function report(message)
    last_error, last_error_at = message, os.date("!%Y-%m-%dT%H:%M:%SZ")
    vim.schedule(function()
      if not cancelled then
        vim.notify("LSP inotifywait: " .. message, vim.log.levels.ERROR)
      end
    end)
  end

  local function clear_deadline(job)
    if job.deadline and not job.deadline:is_closing() then
      job.deadline:stop()
      job.deadline:close()
    end
    job.deadline = nil
  end

  local function stop(watcher, signal)
    if watcher and not watcher.stopped then
      watcher.stopped = true
      clear_deadline(watcher)
      if watcher.process then watcher.process:kill(signal or 2) end
    end
  end

  local function retry(message)
    failures = failures + 1
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    timer = nil
    local delay = retry_delays[failures]
    if not delay then
      exhausted, recovering = true, false
      report(message .. "; recovery exhausted, restart the LSP to retry")
      return
    end
    recovering = true
    total_retries = total_retries + 1
    report(message .. "; retry " .. failures .. "/" .. #retry_delays)
    timer = vim.defer_fn(function()
      timer = nil
      recovering = false
      if not cancelled and not discovery and not replacement then refresh(true) end
    end, delay)
  end

  local function failed(watcher, message, signal)
    if cancelled or watcher.stopped then return end
    if active == watcher then lost_coverage = true end
    -- A ready process must remain healthy for a while before resetting the
    -- retry budget, otherwise rapid start/crash loops would retry forever.
    if watcher.ready_at and vim.uv.hrtime() - watcher.ready_at >= 30e9 then
      failures = 0
    end
    recovering = true
    stop(watcher, signal)
    vim.schedule(function()
      if cancelled then return end
      if replacement == watcher then replacement = nil end
      if active == watcher then active = nil end
      retry(message)
    end)
  end

  local function request_refresh(changed, exists)
    dirty = true
    if changed then changed_dirs[changed:gsub("/$", "")] = exists end
    vim.schedule(function()
      if cancelled or recovering or exhausted or timer or discovery or replacement then
        return
      end
      -- Coalesce directory creation bursts; keep the current watcher serving events.
      timer = vim.defer_fn(function()
        timer = nil
        if not cancelled then refresh() end
      end, 100)
    end)
  end

  local function launch(exclusions)
    local watcher = { output = "", errors = "", exclusions = table.concat(exclusions, "\0") }
    replacement = watcher
    local args = {
      "inotifywait", "--no-dereference", "--monitor", "--recursive",
      -- Keep the tmp directory's own event so it can trigger a rebuild. Suppress
      -- its descendants in the worker, and filter the directory itself below.
      "--exclude", "^" .. regex_escape(prefix) .. "(.*/)?tmp/.+",
      "--event", "create,delete,modify,move",
      "--format", "%w%f%0%e%0", "--no-newline",
      "@" .. prefix .. ".git", path,
    }
    for _, excluded in ipairs(exclusions) do
      table.insert(args, "@" .. excluded)
    end
    local spawned, process = pcall(vim.system, args, {
      -- Readiness messages are part of the handoff protocol below.
      env = { LC_ALL = "C" },
      stdout = function(err, data)
        if cancelled or watcher.stopped then return end
        if err then failed(watcher, err); return end
        if not data then return end
        watcher.output = watcher.output .. data
        while true do
          local first = watcher.output:find("\0", 1, true)
          local second = first and watcher.output:find("\0", first + 1, true)
          if not second then break end
          local fullpath = watcher.output:sub(1, first - 1)
          local flags = watcher.output:sub(first + 1, second - 1)
          local event = flags:match("^[^,]+")
          watcher.output = watcher.output:sub(second + 1)
          if flags:find("ISDIR", 1, true) then
            if event == "CREATE" or event == "MOVED_TO" then
              -- A moved-in directory may already contain nested tmp trees.
              request_refresh(fullpath, true)
            elseif event == "DELETE" or event == "MOVED_FROM" then
              request_refresh(fullpath, false)
            end
          end
          local relative = "/" .. fullpath:sub(#prefix + 1):gsub("/$", "") .. "/"
          local ignored = relative:find("/tmp/", 1, true) or relative:find("/.git/", 1, true)
          local kind = ({ CREATE = 1, MOVED_TO = 1, MODIFY = 2, DELETE = 3, MOVED_FROM = 3 })[event]
          -- Only the active generation dispatches during the overlapping handoff.
          if kind and not ignored and (active == watcher or not active) then
            callback(fullpath, kind)
          end
        end
      end,
      stderr = function(err, data)
        if cancelled or watcher.stopped then return end
        if err then failed(watcher, err); return end
        watcher.errors = watcher.errors .. (data or "")
        while true do
          local newline = watcher.errors:find("\n", 1, true)
          if not newline then break end
          local line = watcher.errors:sub(1, newline - 1)
          watcher.errors = watcher.errors:sub(newline + 1)
          if line == "Watches established." then
            vim.schedule(function()
              if cancelled or watcher.stopped then return end
              local previous = active
              clear_deadline(watcher)
              watcher.ready_at = vim.uv.hrtime()
              active, replacement = watcher, nil
              stop(previous)
              if recovering and timer then
                timer:stop()
                timer:close()
                timer = nil
              end
              recovering = false
              if lost_coverage then
                lost_coverage = false
                resync_clients(path)
              end
              if dirty then request_refresh() end
            end)
          elseif line ~= "" and not line:match("^Setting up watches%.")
            and not line:match("^Watching new directory ") then
            report(line)
          end
        end
      end,
    }, function(result)
      failed(watcher, ("watcher exited (code %s, signal %s)"):format(result.code, result.signal or 0))
    end)
    if spawned then
      watcher.process = process
      watcher.deadline = vim.defer_fn(function()
        if not watcher.ready_at then
          failed(watcher, "watcher readiness timed out after 30s", 9)
        end
      end, 30000)
    else
      failed(watcher, "could not start watcher: " .. tostring(process))
    end
  end

  refresh = function(full)
    dirty = false
    local updates = changed_dirs
    changed_dirs = {}
    local next_exclusions = vim.tbl_extend("force", {}, cached_exclusions or {})
    local scan = {}
    if full or not cached_exclusions then
      next_exclusions = {}
      scan = { path }
    else
      local paths = vim.tbl_keys(updates)
      table.sort(paths, function(a, b) return #a < #b end)
      local covered = {}
      for _, changed in ipairs(paths) do
        local nested = false
        for _, ancestor in ipairs(covered) do
          if vim.startswith(changed, ancestor .. "/") then nested = true; break end
        end
        if not nested then
          table.insert(covered, changed)
          for excluded in pairs(next_exclusions) do
            if excluded == changed or vim.startswith(excluded, changed .. "/") then
              next_exclusions[excluded] = nil
            end
          end
          if updates[changed] then
            local name = vim.fs.basename(changed)
            if name == "tmp" or name == ".git" then
              next_exclusions[changed] = true
            else
              table.insert(scan, changed)
            end
          end
        end
      end
    end
    local function finish(output)
      for excluded in output:gmatch("[^%z]+") do
        next_exclusions[excluded:gsub("/$", "")] = true
      end
      cached_exclusions = next_exclusions
      local exclusions = vim.tbl_keys(next_exclusions)
      table.sort(exclusions)
      if active and active.exclusions == table.concat(exclusions, "\0") then
        if dirty then request_refresh() end
      else
        launch(exclusions)
      end
    end
    if #scan == 0 then
      finish("")
      return
    end
    -- Scan only added/moved subtrees. Full discovery is reserved for startup
    -- and recovery, where the cached directory state may no longer be reliable.
    local args = {
      "fd", "--hidden", "--no-ignore", "--case-sensitive", "--type", "d",
      "--prune", "--absolute-path", "--print0", "^(tmp|\\.git)$",
    }
    vim.list_extend(args, scan)
    local job = {}
    discovery = job
    local spawned, process = pcall(vim.system, args, {}, function(result)
      vim.schedule(function()
        if cancelled or discovery ~= job or job.stopped then return end
        clear_deadline(job)
        job.stopped = true
        discovery = nil
        if result.code ~= 0 then
          retry("directory discovery failed: " .. result.stderr)
        else
          finish(result.stdout)
        end
      end)
    end)
    if spawned then
      job.process = process
      job.deadline = vim.defer_fn(function()
        if cancelled or discovery ~= job or job.stopped then return end
        stop(job, 9)
        discovery = nil
        retry("directory discovery timed out after 30s")
      end, 30000)
    else
      discovery = nil
      retry("could not start discovery: " .. tostring(process))
    end
  end
  refresh()

  return function()
    if not cancelled then
      cancelled = true
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      stop(discovery)
      stop(active)
      stop(replacement)
    end
  end, function()
    local phase = "idle"
    if exhausted then phase = active and "degraded" or "failed"
    elseif recovering then phase = "retrying"
    elseif discovery then phase = active and "refreshing" or "discovering"
    elseif replacement then phase = active and "handoff" or "starting"
    elseif timer then phase = "refresh pending"
    elseif active then phase = "watching" end
    local function pid(job) return job and job.process and job.process.pid end
    local exclusions = vim.tbl_keys(cached_exclusions or {})
    table.sort(exclusions)
    return {
      phase = phase,
      active_pid = pid(active), discovery_pid = pid(discovery), replacement_pid = pid(replacement),
      exclusions = exclusions, retry_budget_used = math.min(failures, #retry_delays),
      retry_budget = #retry_delays, total_retries = total_retries, exhausted = exhausted,
      coverage_lost = lost_coverage, last_error = last_error, last_error_at = last_error_at,
      startup_deadline_seconds = (discovery or replacement) and 30 or nil,
    }
  end
end

function M.watch(path, opts, callback)
  -- Keep symlink spellings: LSP glob patterns and event URIs use the client's path.
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  opts = opts or {}
  local listener = { opts = opts, callback = callback }
  local root = roots[path]
  if not root then
    root = { listeners = {} }
    roots[path] = root
    root.cancel, root.inspect = start(path, function(fullpath, kind)
      for subscriber in pairs(root.listeners) do
        local filters = subscriber.opts
        if (not filters.include_pattern or filters.include_pattern:match(fullpath))
          and (not filters.exclude_pattern or not filters.exclude_pattern:match(fullpath)) then
          subscriber.callback(fullpath, kind)
        end
      end
    end)
  end
  root.listeners[listener] = true
  local cancelled = false
  return function()
    if cancelled then
      return
    end
    cancelled = true
    root.listeners[listener] = nil
    if not next(root.listeners) then
      roots[path] = nil
      root.cancel()
    end
  end
end

function M.status()
  local native = package.loaded["vim.lsp._watchfiles"]
  local result = {
    backend = native and native._watchfunc == M.watch and "custom inotifywait" or "Neovim default/other",
    roots = {},
  }
  for path, root in pairs(roots) do
    local state = root.inspect()
    state.path = path
    state.subscribers = vim.tbl_count(root.listeners)
    table.insert(result.roots, state)
  end
  table.sort(result.roots, function(a, b) return a.path < b.path end)
  return result
end

function M.format_status(status)
  local lines = { "LSP watcher backend: " .. status.backend }
  if #status.roots == 0 then table.insert(lines, "No active custom watcher roots.") end
  for _, root in ipairs(status.roots) do
    table.insert(lines, ("%s — %s (%d subscribers)"):format(root.path, root.phase, root.subscribers))
    table.insert(lines, ("  PIDs: active=%s discovery=%s replacement=%s"):format(
      root.active_pid or "—", root.discovery_pid or "—", root.replacement_pid or "—"))
    table.insert(lines, ("  Retry budget: %d/%d; total retries: %d; lost coverage: %s"):format(
      root.retry_budget_used, root.retry_budget, root.total_retries, tostring(root.coverage_lost)))
    if root.startup_deadline_seconds then
      table.insert(lines, "  Startup stages have a " .. root.startup_deadline_seconds .. "s deadline")
    end
    table.insert(lines, "  Exclusions: " .. #root.exclusions)
    for i = 1, math.min(#root.exclusions, 8) do table.insert(lines, "    " .. root.exclusions[i]) end
    if #root.exclusions > 8 then table.insert(lines, "    … use require('core.lsp-watch').status() for all exclusions") end
    if root.last_error then table.insert(lines, "  Last error (" .. root.last_error_at .. "): " .. root.last_error) end
  end
  return table.concat(lines, "\n")
end

function M.setup()
  vim.api.nvim_create_user_command("LspWatchStatus", function()
    vim.api.nvim_echo({ { M.format_status(M.status()) } }, true, {})
  end, { desc = "Show LSP watcher roots, processes, exclusions and recovery state" })
  if vim.fn.has("linux") == 1 and vim.fn.executable("inotifywait") == 1
    and vim.fn.executable("fd") == 1 then
    -- Private API: recheck this override when upgrading Neovim's watcher backend.
    require("vim.lsp._watchfiles")._watchfunc = M.watch
  end
end

return M
