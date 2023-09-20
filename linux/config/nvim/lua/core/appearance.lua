require("lualine").setup({
  options = {
    theme = "auto",
    icons_enabled = true,
  },
})

vim.cmd.colorscheme "tokyonight-night"

vim.opt.guifont = "Hack:h17"

vim.diagnostic.config({ float = { border = "rounded" } })

vim.cmd("set termguicolors")
require("colorizer").setup()

require("gitsigns").setup()
