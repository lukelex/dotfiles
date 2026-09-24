return {
  "lukelex/railscasts.nvim",
  version = ">=2",
  priority = 1000,
  opts = {},
  init = function()
    vim.cmd.colorscheme "railscasts"
  end
}
