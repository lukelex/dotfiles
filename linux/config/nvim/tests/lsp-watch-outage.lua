-- Real LSP subprocesses: missed disk events recover without losing unsaved text.
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local base = vim.fn.tempname()
local system, notify = vim.system, vim.notify
local workers, ready, buffers, clients = {}, {}, {}, {}
local hold, release
local function wait(predicate, message)
  assert(vim.wait(5000, predicate, 10), message)
end
local function hover(id, buf)
  local client = vim.lsp.get_client_by_id(id)
  if not client or not client.initialized then return nil end
  local response = client:request_sync("textDocument/hover", {
    textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 0 },
  }, 1000, buf)
  return response and response.result and response.result.contents
end
local ok, err = xpcall(function()
  vim.notify = function() end -- The injected crash is expected.
  vim.system = function(args, opts, done)
    if args[1] == "fd" and hold then
      return system(args, opts, function(result) release = function() done(result) end end)
    end
    if args[1] == "inotifywait" then
      local path
      for _, arg in ipairs(args) do
        if arg == base .. "/affected" or arg == base .. "/unrelated" then path = arg end
      end
      assert(path, "unknown watcher workspace")
      local stderr = opts.stderr
      opts.stderr = function(error, data)
        stderr(error, data)
        if data and data:find("Watches established.", 1, true) then ready[path] = true end
      end
      local worker = system(args, opts, done)
      workers[path] = worker
      return worker
    end
    return system(args, opts, done)
  end
  require("core.lsp-watch").setup()
  for _, name in ipairs({ "affected", "unrelated" }) do
    local path = base .. "/" .. name
    vim.fn.mkdir(path, "p")
    vim.fn.writefile({ "before" }, path .. "/state.txt")
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, path .. "/source.txt")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved text" })
    buffers[name] = buf
    clients[name] = vim.lsp.start({
      name = name, root_dir = path,
      cmd = { "python3", config .. "/tests/fixtures/watched-server.py", path },
      capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
    }, { bufnr = buf })
    wait(function() return ready[path] end, "watcher not ready: " .. name)
    assert(hover(clients[name], buf) == "before|unsaved text\n")
  end
  local path = base .. "/affected"
  hold = true
  workers[path]:kill(9)
  wait(function() return release ~= nil end, "no recovery discovery")
  vim.fn.writefile({ "after" }, path .. "/state.txt")
  -- The running LSP is stale: no watcher observed this write.
  assert(hover(clients.affected, buffers.affected) == "before|unsaved text\n")
  hold = false
  release()
  local replacement
  wait(function()
    for _, client in ipairs(vim.lsp.get_clients({ name = "affected" })) do
      if client.id ~= clients.affected and client.initialized then replacement = client; return true end
    end
    return false
  end, "affected client was not reinitialized")
  wait(function()
    return hover(replacement.id, buffers.affected) == "after|unsaved text\n"
  end, "reinitialized client did not read missed change and unsaved buffer")
  assert(not vim.lsp.get_client_by_id(clients.unrelated):is_stopped(), "unrelated workspace restarted")
  assert(vim.bo[buffers.affected].modified, "unsaved buffer was modified or saved")
end, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
vim.wait(3000, function() return #vim.lsp.get_clients() == 0 end, 10)
vim.system, vim.notify = system, notify
vim.fn.delete(base, "rf")
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
print("PASS: stale disk cache resynchronized, unsaved text reattached, unrelated client retained")
