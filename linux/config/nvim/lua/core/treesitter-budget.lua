local M = {}

function M.reason(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then return nil end
  local lines = vim.api.nvim_buf_line_count(buf)
  if lines >= 10000 then return "at least 10,000 lines" end
  if vim.api.nvim_buf_get_offset(buf, lines) >= 512 * 1024 then return "at least 512 KiB" end
end

function M.protect(buf)
  local reason = M.reason(buf)
  if not reason then return false end
  vim.b[buf].treesitter_size_limit = reason
  vim.treesitter.stop(buf)
  local endwise = package.loaded["nvim-treesitter.endwise"]
  if endwise then endwise.detach(buf) end
  vim.bo[buf].indentexpr = ""
  -- Avoid falling back to expensive Vim regex highlighting for the same file.
  vim.bo[buf].syntax = ""
  return true
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufReadPost", "FileType", "TextChanged", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("TreesitterBudget", { clear = true }),
    callback = function(event) M.protect(event.buf) end,
  })
end

return M
