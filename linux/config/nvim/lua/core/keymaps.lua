-- space as the leader key
vim.g.mapleader = " "

local function map(keycode, instruction)
  vim.keymap.set("n", keycode, instruction, {
    noremap = true,
    silent = true
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

-- finger pointing time
map("gb", ":Git blame<CR>")

-- Remap keys in normal mode
map("0", "^")
map("-", "^")
