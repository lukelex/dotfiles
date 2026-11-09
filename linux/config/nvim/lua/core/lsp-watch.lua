local M = {}
local roots = {}

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
  local retry_delays = { 250, 1000, 4000 }
  local refresh
  local prefix = path:gsub("/$", "") .. "/"
  local function report(message)
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
    report(message .. "; retry " .. failures .. "/" .. #retry_delays)
    timer = vim.defer_fn(function()
      timer = nil
      recovering = false
      if not cancelled and not discovery and not replacement then refresh(true) end
    end, delay)
  end

  local function failed(watcher, message, signal)
    if cancelled or watcher.stopped then return end
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
              if dirty then request_refresh() end
            end)
          elseif line ~= "" and not line:match("^Setting up watches%.")
            and not line:match("^Watching new directory ") then
            report(line)
          end
        end
      end,
    }, function(result)
      failed(watcher, "watcher exited with status " .. result.code)
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
    root.cancel = start(path, function(fullpath, kind)
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

function M.setup()
  if vim.fn.has("linux") == 1 and vim.fn.executable("inotifywait") == 1
    and vim.fn.executable("fd") == 1 then
    -- Private API: recheck this override when upgrading Neovim's watcher backend.
    require("vim.lsp._watchfiles")._watchfunc = M.watch
  end
end

return M
