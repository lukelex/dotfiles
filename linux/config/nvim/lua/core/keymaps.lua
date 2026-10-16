-- space as the leader key (set in core.lazy before plugins load)
local function map(keycode, instruction, desc)
  vim.keymap.set("n", keycode, instruction, {
    noremap = true,
    silent = true,
    desc = desc,
  })
end

-- clean the current search
map("<leader>h", ":nohlsearch<CR>", "Clear search highlighting")

-- always horizontally center search results
map("n", "nzzzv", "Next search match, centered")
map("N", "Nzzzv", "Previous search match, centered")

-- navigate through panes with ctrl + hjkl
map("<C-J>", "<C-W><C-J>", "Focus split below")
map("<C-K>", "<C-W><C-K>", "Focus split above")
map("<C-L>", "<C-W><C-L>", "Focus split right")
map("<C-H>", "<C-W><C-H>", "Focus split left")

-- Remap keys in normal mode
map("0", "^", "Go to first nonblank character")
map("-", "^", "Go to first nonblank character")

-- Language Server Protocol
map("<leader>e", function()
  vim.diagnostic.open_float(0, { scope = "line" })
end, "Show line diagnostics")
map("K", function()
  if vim.bo.filetype == "ruby" then
    require("core.hover").ruby()
  else
    vim.lsp.buf.hover()
  end
end, "Show hover documentation")
map("gi", function() require("fzf-lua").lsp_implementations() end, "Find implementations")

map("gdn", vim.diagnostic.goto_next, "Next diagnostic")
map("gdp", vim.diagnostic.goto_prev, "Previous diagnostic")

function ToggleDashUnderscoreOrCase()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local ch = line:sub(col + 1, col + 1)

  if ch == "-" then
    vim.api.nvim_set_current_line(
      line:sub(1, col) .. "_" .. line:sub(col + 2)
    )
  elseif ch == "_" then
    vim.api.nvim_set_current_line(
      line:sub(1, col) .. "-" .. line:sub(col + 2)
    )
  else
    -- fall back to Vim's built-in ~ behavior
    vim.cmd("normal! ~")
  end
end

map("~", ":lua ToggleDashUnderscoreOrCase()<CR>", "Toggle dash/underscore or character case")
