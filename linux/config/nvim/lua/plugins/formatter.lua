local conform = require("conform")

conform.setup({
  formatters_by_ft = {
    javascript = { "prettier" },
    typescript = { "prettier" },
    mustache = { "djlint" },
    json = { "prettier" }
  },
  format_on_save = {
    async = false,
    timeout_ms = 500,
    lsp_fallback = true,
  }
})
