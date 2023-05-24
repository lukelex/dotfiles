vim.g.mapleader = " "

-- clean the current search
vim.api.nvim_set_keymap("n", "<leader>h", ":nohlsearch<CR>", {})

-- always horizontally center search results
vim.api.nvim_set_keymap("n", "n", "nzzzv", {})
vim.api.nvim_set_keymap("n", "N", "Nzzzv", {})

-- navigate through panes with ctrl + hjkl
vim.keymap.set("n", "<C-J>", "<C-W><C-J>")
vim.keymap.set("n", "<C-K>", "<C-W><C-K>")
vim.keymap.set("n", "<C-L>", "<C-W><C-L>")
vim.keymap.set("n", "<C-H>", "<C-W><C-H>")

-- master fucking undo
vim.keymap.set("n", "<F5>", ":UndotreeToggle<CR>")

-- vim.api.nvim_set_keymap("n", "<leader>bl", ":Git blame<CR>", {})
