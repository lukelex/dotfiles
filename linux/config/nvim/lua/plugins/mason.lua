-- local servers = {
--   bashls = {},
--   solargraph = {
--     settings = {
--       solargraph = {
--         diagnostics = false,
--         completion = true,
--         formatting = false
--       }
--     }
--   },
--   standardrb = {}, -- gem install erb
--   ts_ls = {},
--   -- denols = {},
--   eslint = {},
--   svelte = {},
--   html = {},
--   cssls = {},
--   marksman = {},
--   lua_ls = {},
--   sqlls = {},
--   dockerls = {},
--   rust_analyzer = {},
--   slint_lsp = {},
--   docker_compose_language_service = {},
--   tailwindcss = {},
--   -- grammarly = {},
--   vimls = {},
-- }

local servers = {
  "bashls",
  "solargraph",
  "standardrb", -- gem install erb
  "ts_ls",
  "eslint",
  "svelte",
  "html",
  "cssls",
  "marksman",
  "lua_ls",
  "sqlls",
  "dockerls",
  "rust_analyzer",
  "slint_lsp",
  "docker_compose_language_service",
  "tailwindcss",
  "vimls",
}

return {
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    "saghen/blink.cmp",
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
    -- "j-hui/fidget.nvim"
  },
  opts = {
    ensure_installed = {
      "vimls",
      "lua_ls",
      "eslint",
      "standardrb",
      "dockerls",
      "docker_compose_language_service",
    },
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      automatic_enable = false,
    })

    local blink = require("blink.cmp")
    local capabilities = blink.get_lsp_capabilities()

    local lspconfig = require("lspconfig")

    local on_attach = function()
      local opts = { noremap = true, silent = true, buffer = 0 }
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    end

    -- lspconfig.lua_ls.setup({ capabilities = capabilities })
    -- lspconfig.solargraph.setup({
    --   cmd = { "solargraph", "stdio" },
    --   filetypes = { "ruby" },
    --   root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
    --   settings = {
    --     solargraph = {
    --       diagnostics = false,
    --       completion = true,
    --       formatting = false
    --     }
    --   },
    --   on_attach = on_attach,
    --   capabilities = capabilities,
    -- })

    local function merge_tables(first, second)
      local all_options = {}
      for k, v in pairs(first or {}) do all_options[k] = v end
      for k, v in pairs(second or {}) do all_options[k] = v end
      return all_options
    end

    for _, server in ipairs(servers) do
      lspconfig[server].setup(merge_tables({
        on_attach = on_attach,
        capabilities = capabilities,
        -- flags = {
        --   debounce_text_changes = 150,
        -- }
      }), {})
    end
  end
}
