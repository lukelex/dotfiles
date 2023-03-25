vim.g.mapleader = " "

-- clean the current search
vim.api.nvim_set_keymap("n", "<leader>h", ":nohlsearch<CR>", {})

-- always horizontally center search results
vim.api.nvim_set_keymap("n", "n", "nzz", {})
vim.api.nvim_set_keymap("n", "N", "Nzz", {})
