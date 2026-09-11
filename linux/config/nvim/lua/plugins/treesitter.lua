return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" }
    },
    config = function()
      vim.opt.smartindent = true
      local languages = { "ruby", "javascript", "typescript", "svelte", "yaml", "markdown", "css", "html", "bash", "yuck" }

      require("nvim-treesitter").setup {
        install_dir = vim.fn.stdpath("data") .. "/site",
      }
      require("nvim-treesitter").install(languages)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = languages,
        callback = function()
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      require("nvim-treesitter-textobjects").setup {
        select = {
          lookahead = true,
        },
      }

      local select = require("nvim-treesitter-textobjects.select")
      local function textobject(lhs, query, desc)
        vim.keymap.set({ "x", "o" }, lhs, function()
          select.select_textobject(query, "textobjects")
        end, { desc = desc })
      end

      textobject("ac", "@class.outer", "Select around class")
      textobject("ic", "@class.inner", "Select inside class")
      textobject("ar", "@ruby.outer", "Select around Ruby structure")
      textobject("ir", "@ruby.inner", "Select inside Ruby structure")
      textobject("am", "@function.outer", "Select around a method/function definition")
      textobject("im", "@function.inner", "Select inside a method/function definition")
      textobject("af", "@function.outer", "Select around a method/function definition")
      textobject("if", "@function.inner", "Select inside a method/function definition")
    end
  },
}
