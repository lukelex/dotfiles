return {
  {
    "stevearc/conform.nvim",
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          javascript = { "prettierd", "prettier", stop_after_first = true },
          typescript = { "prettierd", "prettier", stop_after_first = true },
          mustache = { "djlint" },
          json = { "deno" },
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
