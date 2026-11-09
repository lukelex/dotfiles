local M = {}

-- Neovim's built-in inotify backend filters events only after recursively
-- installing watches. Exclude tmp trees in inotifywait itself instead.
function M.watch(path, opts, callback)
  opts = opts or {}
  local pending = ""
  local cancelled = false
  local function report(message)
    vim.schedule(function()
      if not cancelled then
        vim.notify("LSP inotifywait: " .. message, vim.log.levels.ERROR)
      end
    end)
  end

  local args = {
    "inotifywait", "--quiet", "--no-dereference", "--monitor", "--recursive",
    "--exclude", "(^|/)tmp(/|$)",
    "--event", "create,delete,modify,move",
    -- NUL-separated fields preserve spaces and newlines in filenames.
    "--format", "%w%f%0%e%0", "--no-newline",
    "@" .. path .. "/.git", path,
  }
  local options = {
    stdout = function(err, data)
      if err then
        report(err)
        return
      end
      if cancelled or not data then
        return
      end
      pending = pending .. data
      while true do
        local first = pending:find("\0", 1, true)
        local second = first and pending:find("\0", first + 1, true)
        if not second then
          break
        end
        local fullpath = pending:sub(1, first - 1)
        local event = pending:sub(first + 1, second - 1):match("^[^,]+")
        pending = pending:sub(second + 1)
        local kind = ({ CREATE = 1, MOVED_TO = 1, MODIFY = 2, DELETE = 3, MOVED_FROM = 3 })[event]
        if kind
          and (not opts.include_pattern or opts.include_pattern:match(fullpath))
          and (not opts.exclude_pattern or not opts.exclude_pattern:match(fullpath)) then
          callback(fullpath, kind)
        end
      end
    end,
    stderr = function(err, data)
      if err or (data and data:match("%S")) then
        report(err or data)
      end
    end,
  }
  local function on_exit(result)
    if result.code ~= 0 and not cancelled then
      report("watcher exited with status " .. result.code)
    end
  end
  local process
  -- --exclude suppresses events but does not prune the initial recursive scan.
  -- Discover explicit @ exclusions in a background process, pruning tmp trees.
  -- New tmp directories have events suppressed; their watches are pruned on restart.
  process = vim.system({
    "fd", "--hidden", "--no-ignore", "--case-sensitive", "--type", "d",
    "--prune", "--absolute-path", "--print0", "^(tmp|\\.git)$", path,
  }, {}, function(result)
    vim.schedule(function()
      if cancelled then
        return
      end
      if result.code ~= 0 then
        report("directory discovery failed: " .. result.stderr)
        return
      end
      for excluded in result.stdout:gmatch("[^%z]+") do
        table.insert(args, "@" .. excluded:gsub("/$", ""))
      end
      process = vim.system(args, options, on_exit)
    end)
  end)

  return function()
    if not cancelled then
      cancelled = true
      process:kill(2)
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
