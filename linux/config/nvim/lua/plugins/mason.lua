local servers = {
  "bashls",
  "solargraph",
  "standardrb", -- gem install erb
  "ts_ls",
  -- "denols",
  "eslint",
  "svelte",
  "html",
  "cssls",
  "marksman",
  "lua_ls",
  "sqlls",
  "dockerls",
  "docker_compose_language_service",
  "rust_analyzer",
  "slint_lsp",
  "tailwindcss",
  "vimls",
  "gopls"
}

return {
  "mason-org/mason-lspconfig.nvim",
  dependencies = {
    "saghen/blink.cmp",
    "neovim/nvim-lspconfig",
    { "mason-org/mason.nvim", opts = {} },
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      automatic_enable = false,
      ensure_installed = servers
    })

    local blink = require("blink.cmp")
    local capabilities = blink.get_lsp_capabilities()

    vim.lsp.config('*', {
      debounce_text_changes = 150,
      capabilities = capabilities
    })

    vim.lsp.config("solargraph", {
      root_markers = { "backend", "Gemfile", ".git" },
      init_options = { formatting = false },
      settings = {
        solargraph = {
          diagnostics = false,
          completion = true,
          formatting = false
        }
      },
    })

    vim.lsp.enable(servers)
  end
}
