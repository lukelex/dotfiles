local servers = {
  "bashls",
  "solargraph",
  "tsserver",
  "vuels",
  "html",
  "cssls",
  "marksman",
  "lua_ls",
  "sqlls",
  "dockerls",
  "docker_compose_language_service",
  "vimls",
}

require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = servers
})

local on_attach = function()
  local opts = { noremap = true, silent = true, buffer = 0 }

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
end

local capabilities = require("cmp_nvim_lsp").default_capabilities()

local config = require("lspconfig")
for _, lsp in ipairs(servers) do
  config[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end
