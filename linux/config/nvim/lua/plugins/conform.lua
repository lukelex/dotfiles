return {
  {
    "stevearc/conform.nvim",
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          javascript = { "prettierd", stop_after_first = true },
          typescript = { "prettierd", stop_after_first = true },
          mustache = { "djlint" },
          markdown = { "prettierd" },
          json = { "prettierd" },
          jsonc = { "prettierd" },
          bash = { "beautysh" },
          sh = { "beautysh" },
          zsh = { "beautysh" },
          yaml = { "yamlfmt" },
        },
        formatters = {
          beautysh = {
            args = { "--indent-size", "2", "-" },
          },
        },
        format_on_save = {
          async = false,
          timeout_ms = 500,
          lsp_fallback = true,
        }
      })
    end
  }
}
