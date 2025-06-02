require "core.editor"
require "core.keymaps"
require "core.appearance"
require "core.lazy"

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
