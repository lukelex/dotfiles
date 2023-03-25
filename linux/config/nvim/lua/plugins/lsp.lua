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

local config = require("lspconfig")
config.ruby_ls.setup {
  on_attach = on_attach,
}
config.gdscript.setup {
  on_attach = on_attach,
}
config.lua_ls.setup {
  on_attach = on_attach,
}
config.dockerls.setup {
  on_attach = on_attach,
}
config.vuels.setup {
  on_attach = on_attach,
}
config.marksman.setup {
  on_attach = on_attach,
}
config.docker_compose_language_service.setup {
  on_attach = on_attach,
}
