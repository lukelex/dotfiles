require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "bashls",
    "ruby_ls",
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
})

local on_attach = function()
  local opts = { noremap = true, silent = true, buffer = 0 }

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
end

local capabilities = require("cmp_nvim_lsp").default_capabilities()

local config = require("lspconfig")
config.ruby_ls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.gdscript.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.lua_ls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.dockerls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.tsserver.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.vuels.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.cssls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.marksman.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
config.docker_compose_language_service.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}

require("plugins.lsp.appearance")
