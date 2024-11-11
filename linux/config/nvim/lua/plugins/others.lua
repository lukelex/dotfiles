require("nvim-treesitter.configs").setup {
  endwise = {
    enable = true,
  },
}

vim.opt.termguicolors = true
require("colorizer").setup()

require("mini.cursorword").setup({ delay = 50 })
require("mini.pairs").setup()
require("mini.diff").setup({
  mappings = {
    apply = "gha",
  }
})
require("mini.indentscope").setup()
