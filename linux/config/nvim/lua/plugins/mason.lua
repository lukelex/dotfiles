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
}

return {
  "mason-org/mason-lspconfig.nvim",
  dependencies = {
    "saghen/blink.cmp",
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

    local lsp = require("lspconfig")

    lsp.vimls.setup({ capabilities = capabilities })
    lsp.bashls.setup({ capabilities = capabilities })
    lsp.lua_ls.setup({ capabilities = capabilities })
    lsp.sqlls.setup({ capabilities = capabilities })
    lsp.marksman.setup({ capabilities = capabilities })

    lsp.dockerls.setup({ capabilities = capabilities })
    lsp.docker_compose_language_service.setup({ capabilities = capabilities })

    lsp.rust_analyzer.setup({ capabilities = capabilities })
    lsp.slint_lsp.setup({ capabilities = capabilities })

    lsp.standardrb.setup({ capabilities = capabilities })
    lsp.solargraph.setup({
      cmd = { "solargraph", "stdio" },
      filetypes = { "ruby" },
      root_dir = lsp.util.root_pattern("Gemfile", ".git"),
      settings = {
        solargraph = {
          diagnostics = false,
          completion = true,
          formatting = false
        }
      },
      capabilities = capabilities,
    })

    lsp.html.setup({ capabilities = capabilities })
    lsp.cssls.setup({ capabilities = capabilities })
    lsp.tailwindcss.setup({ capabilities = capabilities })
    lsp.ts_ls.setup({ capabilities = capabilities })
    lsp.eslint.setup({ capabilities = capabilities })
    local svelte_lsp_capabilities = vim.tbl_deep_extend("force", {}, capabilities)
    svelte_lsp_capabilities.workspace = { didChangeWatchedFiles = false }
    lsp.svelte.setup({
      capabilities = svelte_lsp_capabilities,
      filetypes = { "svelte" },
    })
  end
}
