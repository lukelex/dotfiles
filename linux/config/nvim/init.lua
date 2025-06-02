require "core.editor"
require "core.keymaps"
require "core.appearance"
require "core.lazy"

-- Disable Vi compatibility mode
vim.o.compatible = false

-- Disable automatic filetype detection temporarily (similar to `filetype off`)
vim.g.do_filetype_lua = 1
vim.g.did_load_filetypes = 0

-- Enable syntax highlighting
vim.cmd("syntax on")

-- Remap keys in normal mode
vim.keymap.set("n", "0", "^", { noremap = true })
vim.keymap.set("n", "-", "^", { noremap = true })

-- Git commit settings: wrap at 72 chars and enable spell check
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.textwidth = 72
    vim.opt_local.spell = true
  end,
})

-- Enable spell-based word completion
vim.opt.complete:append("kspell")

-- Define user commands
vim.api.nvim_create_user_command("PrettyPrintJSON", "%!python -m json.tool", {})
vim.api.nvim_create_user_command("PrettyPrintHTML", "!tidy -mi -html -wrap 0 %", {})
vim.api.nvim_create_user_command("PrettyPrintXML", "!tidy -mi -xml -wrap 0 %", {})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "compose.yaml",
  callback = function()
    vim.bo.filetype = "yaml.docker-compose"
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.md",
  callback = function()
    vim.opt_local.spell = true
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = ".env.*",
  callback = function()
    vim.bo.filetype = "sh"
  end,
})
