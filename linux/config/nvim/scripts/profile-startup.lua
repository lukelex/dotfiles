-- Loaded before init.lua by profile-startup.py; never part of normal startup.
local output = assert(vim.env.NVIM_PROFILE_OUTPUT)
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local began = vim.uv.hrtime()
local function elapsed() return (vim.uv.hrtime() - began) / 1e6 end
local result = { gaps = {}, attachments = {}, slow_calls = {}, notifications = {} }
local last, entered = began, false
local max_gap, post_enter_max, post_restore_max = 0, 0, 0
local restored_at
local pending = false
local timer = vim.uv.new_timer()
timer:start(10, 10, function()
  if pending then return end
  pending = true
  vim.schedule(function()
    pending = false
    local now = vim.uv.hrtime()
    local gap = (now - last) / 1e6
    max_gap = math.max(max_gap, gap)
    if entered then post_enter_max = math.max(post_enter_max, gap) end
    if restored_at and last >= restored_at then post_restore_max = math.max(post_restore_max, gap) end
    if gap > 50 then table.insert(result.gaps, { at_ms = elapsed(), gap_ms = gap }) end
    last = now
  end)
end)

-- Redirect auto-session before its normal setup, preserving the configured hooks.
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/auto-session")
local sessions = require("auto-session.config")
local setup = sessions.setup
sessions.setup = function(opts)
  opts = vim.deepcopy(opts or {})
  opts.root_dir = output .. "/sessions/"
  opts.auto_save = false
  opts.pre_restore_cmds = opts.pre_restore_cmds or {}
  opts.post_restore_cmds = opts.post_restore_cmds or {}
  table.insert(opts.pre_restore_cmds, function() result.restore_start_ms = elapsed() end)
  table.insert(opts.post_restore_cmds, function()
    result.restore_end_ms = elapsed()
    result.session_restored = true
    restored_at = vim.uv.hrtime()
  end)
  setup(opts)
end

-- Capture expensive synchronous subprocesses, including any plugin startup probes.
for _, name in ipairs({ "system", "systemlist" }) do
  local original = vim.fn[name]
  vim.fn[name] = function(...)
    local start = vim.uv.hrtime()
    local values = { original(...) }
    local ms = (vim.uv.hrtime() - start) / 1e6
    if ms > 10 then table.insert(result.slow_calls, { function_name = name, ms = ms }) end
    return unpack(values)
  end
end
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    result.lazy_done_ms = elapsed()
    if vim.env.NVIM_PROFILE_TS == "async" then vim.g._ts_force_sync_parsing = false end
    local notify = vim.notify
    vim.notify = function(message, level, opts)
      table.insert(result.notifications, { message = tostring(message), level = level })
      return notify(message, level, opts)
    end
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    entered = true
    last = vim.uv.hrtime()
    result.vim_enter_ms = elapsed()
  end,
})
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    table.insert(result.attachments, { name = client.name, root = client.config.root_dir, at_ms = elapsed() })
  end,
})
vim.defer_fn(function()
  timer:stop()
  timer:close()
  result.max_gap_ms = max_gap
  result.post_vim_enter_max_gap_ms = post_enter_max
  result.post_restore_max_gap_ms = post_restore_max
  result.duration_ms = elapsed()
  result.treesitter_sync = vim.g._ts_force_sync_parsing == true
  result.ui = vim.api.nvim_list_uis()
  result.buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      table.insert(result.buffers, vim.api.nvim_buf_get_name(buf))
    end
  end
  result.clients = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    table.insert(result.clients, { name = client.name, root = client.config.root_dir })
  end
  result.messages = vim.api.nvim_exec2("messages", { output = true }).output
  vim.fn.writefile({ vim.json.encode(result) }, output .. "/result.json")
  vim.cmd("qa!")
end, tonumber(vim.env.NVIM_PROFILE_SECONDS) * 1000)
