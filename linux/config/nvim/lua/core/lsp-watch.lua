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
  local refresh
  local prefix = path:gsub("/$", "") .. "/"
  local function report(message)
    vim.schedule(function()
      if not cancelled then
        vim.notify("LSP inotifywait: " .. message, vim.log.levels.ERROR)
      end
    end)
  end

  local function stop(watcher)
    if watcher and not watcher.stopped then
      watcher.stopped = true
      watcher.process:kill(2)
    end
  end

  local function request_refresh()
    dirty = true
    vim.schedule(function()
      if cancelled or timer or discovery or replacement then
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
    watcher.process = vim.system(args, {
      -- Readiness messages are part of the handoff protocol below.
      env = { LC_ALL = "C" },
      stdout = function(err, data)
        if cancelled or watcher.stopped then return end
        if err then report(err); return end
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
          if flags:find("ISDIR", 1, true) and (event == "CREATE" or event == "MOVED_TO") then
            -- A normal directory moved in may already contain nested tmp trees.
            request_refresh()
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
        if err then report(err); return end
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
              active, replacement = watcher, nil
              stop(previous)
              if dirty then request_refresh() end
            end)
          elseif line ~= "" and not line:match("^Setting up watches%.")
            and not line:match("^Watching new directory ") then
            report(line)
          end
        end
      end,
    }, function(result)
      if not cancelled and not watcher.stopped then
        vim.schedule(function()
          if replacement == watcher then replacement = nil end
          if active == watcher then active = nil end
        end)
        report("watcher exited with status " .. result.code)
      end
    end)
  end

  refresh = function()
    dirty = false
    -- Explicit @ exclusions prune scans; --exclude alone only filters events.
    discovery = vim.system({
      "fd", "--hidden", "--no-ignore", "--case-sensitive", "--type", "d",
      "--prune", "--absolute-path", "--print0", "^(tmp|\\.git)$", path,
    }, {}, function(result)
      vim.schedule(function()
        discovery = nil
        if cancelled then return end
        if result.code ~= 0 then
          report("directory discovery failed: " .. result.stderr)
          return
        end
        local exclusions = {}
        for excluded in result.stdout:gmatch("[^%z]+") do
          table.insert(exclusions, (excluded:gsub("/$", "")))
        end
        table.sort(exclusions)
        if active and active.exclusions == table.concat(exclusions, "\0") then
          -- inotifywait already watches new normal directories; rebuild only
          -- when the exclusions actually changed.
          if dirty then request_refresh() end
        else
          launch(exclusions)
        end
      end)
    end)
  end
  refresh()

  return function()
    if not cancelled then
      cancelled = true
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if discovery then discovery:kill(2) end
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
