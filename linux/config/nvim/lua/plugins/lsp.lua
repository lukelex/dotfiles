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

require("lspconfig").ruby_ls.setup {}
require("lspconfig").gdscript.setup {}
require("lspconfig").lua_ls.setup {}
require("lspconfig").dockerls.setup {}
require("lspconfig").docker_compose_language_service.setup {}
