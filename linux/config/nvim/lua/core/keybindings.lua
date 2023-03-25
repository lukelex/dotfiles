-- clean the current search
vim.api.nvim_set_keymap("n", "<leader>h", ":nohlsearch<CR>", {})

-- always horizontally center search results
vim.api.nvim_set_keymap("n", "n", "nzz", {})
vim.api.nvim_set_keymap("n", "N", "Nzz", {})

-- vim.api.nvim_set_keymap("v", "<Leader>b", ":<C-U>!git blame <C-R>=expand("%:p") <CR> \| sed -n <C-R>=line("'<") <CR>,<C-R>=line("'>") <CR>p <CR>")
