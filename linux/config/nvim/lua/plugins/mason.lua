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
  "williamboman/mason-lspconfig.nvim",
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

    local lspconfig = require("lspconfig")

    local on_attach = function()
      local opts = { noremap = true, silent = true, buffer = 0 }
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
      vim.keymap.set("n", "<leader>e", function() vim.diagnostic.open_float(0, { scope = "line" }) end)
    end

    lspconfig.vimls.setup({ capabilities = capabilities })
    lspconfig.bashls.setup({ capabilities = capabilities })
    lspconfig.lua_ls.setup({ capabilities = capabilities })
    lspconfig.sqlls.setup({ capabilities = capabilities })
    lspconfig.marksman.setup({ capabilities = capabilities })

    lspconfig.dockerls.setup({ capabilities = capabilities })
    lspconfig.docker_compose_language_service.setup({ capabilities = capabilities })

    lspconfig.rust_analyzer.setup({ capabilities = capabilities })
    lspconfig.slint_lsp.setup({ capabilities = capabilities })

    lspconfig.standardrb.setup({ capabilities = capabilities })
    lspconfig.solargraph.setup({
      cmd = { "solargraph", "stdio" },
      filetypes = { "ruby" },
      root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
      settings = {
        solargraph = {
          diagnostics = false,
          completion = true,
          formatting = false
        }
      },
      on_attach = on_attach,
      capabilities = capabilities,
    })

    lspconfig.html.setup({ capabilities = capabilities })
    lspconfig.cssls.setup({ capabilities = capabilities })
    lspconfig.tailwindcss.setup({ capabilities = capabilities })
    lspconfig.ts_ls.setup({ capabilities = capabilities })
    lspconfig.eslint.setup({ capabilities = capabilities })
    local svelte_lsp_capabilities = vim.tbl_deep_extend("force", {}, capabilities)
    svelte_lsp_capabilities.workspace = { didChangeWatchedFiles = false }
    lspconfig.svelte.setup({
      capabilities = svelte_lsp_capabilities,
      filetypes = { "svelte" },
    })
  end
}
