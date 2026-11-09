local M = {}
local helper = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/scripts/memory-snapshot.py"
local buffer, process, generation = nil, nil, 0

local function mib(value)
  return type(value) == "number" and string.format("%.1f", value / 1024) or "?"
end

function M.format(snapshot, clients)
  local lines = {
    "Neovim memory — " .. os.date("%Y-%m-%d %H:%M:%S"),
    "r: refresh   q: close   Units: MiB",
    "PSS shares shared pages proportionally; private is exclusive RAM. RSS double-counts shared pages.",
    "Swap is proportional swap usage, separate from resident RAM.",
    "",
  }
  table.insert(lines, string.format("%-8s %10s %10s %10s %10s  %s", "PID", "PSS", "Private", "RSS", "Swap", "Process"))
  for _, row in ipairs(snapshot.processes) do
    local label = row.label:gsub("[%c]", " ")
    table.insert(lines, string.format("%-8d %10s %10s %10s %10s  %s%s%s", row.pid,
      mib(row.pss_kib), mib(row.private_kib), mib(row.rss_kib), mib(row.swap_kib),
      string.rep("  ", row.depth), label, row.error and " [unavailable: " .. row.error .. "]" or ""))
  end
  local totals = snapshot.totals
  table.insert(lines, string.format("%-8s %10s %10s %10s %10s", "TOTAL", mib(totals.pss_kib),
    mib(totals.private_kib), mib(totals.rss_kib), mib(totals.swap_kib)))
  for key, count in pairs(snapshot.missing) do
    if count > 0 then table.insert(lines, ("Partial %s total: %d process(es) unavailable."):format(key, count)) end
  end
  table.insert(lines, "")
  table.insert(lines, "Active LSP clients / workspaces:")
  if #clients == 0 then table.insert(lines, "  None") end
  for _, client in ipairs(clients) do
    table.insert(lines, ("  %s (#%d): %s"):format(client.name, client.id, client.root))
  end
  table.insert(lines, "")
  table.insert(lines, "Snapshot of this Neovim process tree; remote/detached servers are not included.")
  return lines
end

local function render(lines)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then return end
  local flattened = {}
  for _, line in ipairs(lines) do
    vim.list_extend(flattened, vim.split(line, "\n", { plain = true }))
  end
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, flattened)
  vim.bo[buffer].modifiable = false
end

local function cancel()
  generation = generation + 1
  if process then process:kill(15); process = nil end
end

function M.refresh()
  cancel()
  local current = generation
  render({ "Collecting memory usage in the background…", "q: close" })
  local clients = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    local folders = {}
    for _, folder in ipairs(client.workspace_folders or {}) do
      table.insert(folders, vim.fn.fnamemodify(vim.uri_to_fname(folder.uri), ":~"))
    end
    table.insert(clients, { name = client.name, id = client.id,
      root = #folders > 0 and table.concat(folders, ", ") or client.config.root_dir or "(no root)" })
  end
  table.sort(clients, function(a, b) return a.id < b.id end)
  local ok, child = pcall(vim.system, { "python3", helper }, {
    stdin = vim.json.encode({ pid = vim.fn.getpid() }), text = true, timeout = 10000,
  }, function(result)
    vim.schedule(function()
      if current ~= generation or not buffer or not vim.api.nvim_buf_is_valid(buffer) then return end
      process = nil
      if result.code ~= 0 then
        render({ "Memory snapshot failed: " .. vim.trim(result.stderr or ""), "r: retry   q: close" })
        return
      end
      local decoded, snapshot = pcall(vim.json.decode, result.stdout)
      render(decoded and M.format(snapshot, clients) or { "Invalid memory snapshot output", "r: retry   q: close" })
    end)
  end)
  if ok then process = child else render({ "Cannot start memory snapshot: " .. tostring(child) }) end
end

function M.open()
  if vim.fn.has("linux") ~= 1 then
    vim.notify("NvimMemory requires Linux /proc", vim.log.levels.ERROR)
    return
  end
  local windows = buffer and vim.fn.win_findbuf(buffer) or {}
  if #windows > 0 then
    vim.api.nvim_set_current_win(windows[1])
  else
    vim.cmd("botright 18new")
    buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buffer, "NvimMemory")
    vim.bo[buffer].buftype = "nofile"
    vim.bo[buffer].bufhidden = "wipe"
    vim.bo[buffer].swapfile = false
    vim.bo[buffer].filetype = "text"
    vim.bo[buffer].modifiable = false
    vim.wo.wrap, vim.wo.number, vim.wo.relativenumber = false, false, false
    vim.keymap.set("n", "r", M.refresh, { buffer = buffer, desc = "Refresh memory snapshot" })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buffer, desc = "Close memory snapshot" })
    vim.api.nvim_create_autocmd("BufWipeout", { buffer = buffer, once = true, callback = cancel })
  end
  M.refresh()
end

return M
