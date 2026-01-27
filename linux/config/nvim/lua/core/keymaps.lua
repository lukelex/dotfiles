-- space as the leader key
vim.g.mapleader = " "

local function map(keycode, instruction)
  vim.keymap.set("n", keycode, instruction, {
    noremap = true,
    silent = true,
  })
end

-- clean the current search
map("<leader>h", ":nohlsearch<CR>")

-- always horizontally center search results
map("n", "nzzzv")
map("N", "Nzzzv")

-- navigate through panes with ctrl + hjkl
map("<C-J>", "<C-W><C-J>")
map("<C-K>", "<C-W><C-K>")
map("<C-L>", "<C-W><C-L>")
map("<C-H>", "<C-W><C-H>")

-- Remap keys in normal mode
map("0", "^")
map("-", "^")

-- Language Server Protocol
map("<leader>e", function()
  vim.diagnostic.open_float(0, { scope = "line" })
end)
map("K", vim.lsp.buf.hover)
map("gi", vim.lsp.buf.implementation)

map("gdn", vim.diagnostic.goto_next)
map("gdp", vim.diagnostic.goto_prev)

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

map("~", ":lua ToggleDashUnderscoreOrCase()<CR>")
