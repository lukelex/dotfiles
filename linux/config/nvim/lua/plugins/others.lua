require("nvim-treesitter.configs").setup {
  endwise = {
    enable = true,
  },
}

vim.opt.termguicolors = true
require("colorizer").setup()

require("ibl").setup {
  scope = { enabled = false },
}

require('mini.cursorword').setup({ delay = 50 })
require('mini.pairs').setup()
