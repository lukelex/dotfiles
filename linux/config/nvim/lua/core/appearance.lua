vim.cmd("colorscheme nightfly")
vim.g.nightflyCursorColor = true
vim.g.nightflyNormalFloat = true

require("lualine").setup({
  options = {
    theme = "auto",
    icons_enabled = true,
  },
})

vim.opt.guifont = "Hack:h17"

vim.diagnostic.config({ float = { border = "rounded" } })

vim.cmd("set termguicolors")
require("colorizer").setup()

require("gitsigns").setup()
