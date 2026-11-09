-- Run with -u NONE -l; uses installed parsers, creates only scratch buffers.
-- Optional first argument: a source file; otherwise benchmark generated fixtures.
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter")
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local guarded = arg[1] == "--guarded"
local function benchmark(name, lang, lines)
  collectgarbage("collect")
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if guarded then
    local start = vim.uv.hrtime()
    local protected = require("core.treesitter-budget").protect(buf)
    if protected then
      print(vim.json.encode({ name = name, lines = #lines, skipped = true,
        guard_ms = (vim.uv.hrtime() - start) / 1e6 }))
      vim.api.nvim_buf_delete(buf, { force = true })
      return
    end
  end
  local parser = vim.treesitter.get_parser(buf, lang)
  local start = vim.uv.hrtime()
  parser:parse(true)
  local initial = (vim.uv.hrtime() - start) / 1e6
  vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, { " " })
  start = vim.uv.hrtime()
  parser:parse(true)
  local edit = (vim.uv.hrtime() - start) / 1e6
  print(vim.json.encode({ name = name, bytes = vim.api.nvim_buf_get_offset(buf, #lines),
    lines = #lines, initial_parse_ms = initial, incremental_parse_ms = edit }))
  vim.api.nvim_buf_delete(buf, { force = true })
end
if arg[1] and not guarded then
  local ft = vim.filetype.match({ filename = arg[1] })
  benchmark(arg[1], vim.treesitter.language.get_lang(ft), vim.fn.readfile(arg[1]))
else
  for _, count in ipairs({ 1000, 10000, 30000 }) do
    local ts, yaml, ruby = {}, {}, {}
    for i = 1, count do
      ts[i] = ('export const item%d = { id: %d, label: "generated item" };'):format(i, i)
      yaml[i] = ('item%d: {id: %d, label: "generated item"}'):format(i, i)
      ruby[i] = ('ITEM_%d = { id: %d, label: "generated item" }'):format(i, i)
    end
    benchmark("generated TypeScript", "typescript", ts)
    benchmark("generated YAML", "yaml", yaml)
    benchmark("generated Ruby", "ruby", ruby)
  end
  benchmark("minified JavaScript", "javascript", { "const items = [" .. string.rep('{id:1,label:"item"},', 30000) .. "];" })
end
