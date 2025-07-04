return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
      "nvim-treesitter/nvim-treesitter-textobjects"
    },
    config = function()
      -- require("nvim-treesitter.configs").setup(opts)
      require("nvim-treesitter.configs").setup {
        ensure_installed = {
          "ruby",
          "javascript",
          "typescript",
          "yaml",
          "markdown",
          "css",
          "html",
          "bash",
        },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        endwise = {
          enable = false,
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

              ["af"] = { query = "@function.outer", desc = "Select around a method/function definition" },
              ["if"] = { query = "@function.inner", desc = "Select inside a method/function definition" },
            }
          }
        }
      }
    end
  },
  {
    "nvim-treesitter/playground",
    event = { "BufRead" },
  }
}
