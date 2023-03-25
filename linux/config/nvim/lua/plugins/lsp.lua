require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "bashls",
    "ruby_ls",
    "tsserver",
    "vuels",
    "html",
    "marksman",
    "lua_ls",
    "sqlls",
    "dockerls",
    "docker_compose_language_service",
    "vimls",
  }
})

local on_attach = function()
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = 0 })
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = 0 })
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { buffer = 0 })
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

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
config.vuels.setup {
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
