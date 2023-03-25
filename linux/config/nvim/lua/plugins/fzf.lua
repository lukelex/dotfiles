vim.api.nvim_set_keymap("n", "<Leader>p", ":FZF<CR>", {})
vim.api.nvim_set_keymap("n", "<Leader>u", ":Buffers<CR>", {})

vim.g.fzf_preview_window = { "right:50%", "ctrl-/" }
vim.g.fzf_buffers_jump = 1
vim.g.fzf_tags_command = "ctags -R --exclude=node_modules --exclude=public"
