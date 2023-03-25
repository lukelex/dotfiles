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
