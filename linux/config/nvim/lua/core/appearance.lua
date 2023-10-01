vim.opt.guifont = "Hack:h17"

vim.diagnostic.config({ float = { border = "rounded" } })

vim.cmd("set termguicolors")
require("colorizer").setup()

require("gitsigns").setup()

require("ibl").setup {
  scope = { enabled = false },
}

require("lualine").setup({
  options = {
    theme = "railscasts",
    icons_enabled = true,
  },
})

vim.cmd.colorscheme "railscasts"
