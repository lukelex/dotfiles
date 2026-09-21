return {
  "lukelex/railscasts.nvim",
  version = "v1",
  priority = 1000,
  dependencies = {
    "rktjmp/lush.nvim",
    "nvim-treesitter/nvim-treesitter"
  },
  config = function()
    vim.cmd.colorscheme "railscasts"
  end
}
