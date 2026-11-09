local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local budget = require("core.treesitter-budget")
local buf = vim.api.nvim_create_buf(false, false)
local started, detached = 0, 0
local ok, err = xpcall(function()
  -- Exercise the real plugin setup while preventing installations and parsing.
  package.loaded["nvim-treesitter"] = { setup = function() end, install = function() end }
  package.loaded["nvim-treesitter-textobjects"] = { setup = function() end }
  package.loaded["nvim-treesitter-textobjects.select"] = { select_textobject = function()
    error("textobject parsed a protected buffer")
  end }
  package.loaded["nvim-treesitter.endwise"] = { detach = function() detached = detached + 1 end }
  vim.treesitter.start = function() started = started + 1 end
  dofile(config .. "/lua/plugins/treesitter.lua")[1].config()
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local ordinary = true" })
  vim.api.nvim_exec_autocmds("FileType", { pattern = "ruby" })
  assert(started == 1 and vim.bo[buf].indentexpr ~= "", "ordinary file lost Tree-sitter")
  local lines = {}
  for i = 1, 10000 do lines[i] = "x" end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  assert(budget.reason(buf) == "at least 10,000 lines")
  assert(vim.bo[buf].indentexpr == "" and detached > 0, "growth did not disable synchronous helpers")
  vim.api.nvim_exec_autocmds("FileType", { pattern = "ruby" })
  assert(started == 1, "large buffer started highlighting")
  for _, map in ipairs(vim.api.nvim_get_keymap("x")) do
    if map.desc == "Select around a method/function definition" then map.callback() end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep("x", 512 * 1024) })
  assert(budget.reason(buf) == "at least 512 KiB", "minified file missed size guard")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "small again" })
  vim.api.nvim_exec_autocmds("FileType", { pattern = "ruby" })
  assert(started == 2 and not vim.b[buf].treesitter_size_limit, "reload did not reenable small-buffer features")
end, debug.traceback)
vim.api.nvim_buf_delete(buf, { force = true })
if not ok then io.stderr:write(err .. "\n"); os.exit(1) end
print("PASS: ordinary files, large/minified buffers, growth, indentation/endwise/textobject guards")
