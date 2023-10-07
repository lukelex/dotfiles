require("nvim-treesitter.configs").setup {
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  textobjects = {
    select = {
      enable = true,
      -- Automatically jump forward to closest text object
      lookahead = true,
      keymaps = {
        ["ac"] = { query = "@class.outer", desc = "Select around class" },
        ["ic"] = { query = "@class.inner", desc = "Select inside class" },

        ["am"] = { query = "@function.outer", desc = "Select around a method/function definition" },
        ["im"] = { query = "@function.inner", desc = "Select inside a method/function definition" },
      }
    }
  }
}
