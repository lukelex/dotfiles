return {
  {
    "saghen/blink.cmp",
    lazy = false,
    event = { "InsertEnter" },
    version = "1.*",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "neovim/nvim-lspconfig",
      "L3MON4D3/LuaSnip",
      -- "williamboman/mason.nvim",
      -- "williamboman/mason-lspconfig.nvim",
      -- "j-hui/fidget.nvim"
    },
    opts = {
      keymap = {
        -- preset = "default",
        -- preset = "super-tab",

        preset = "enter",
        -- ["<Tab>"] = { "snippet_forward", "fallback" },
        -- ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

        -- preset = "none",
        -- ['<C-space>'] = { function(cmp) cmp.show({ providers = { 'snippets' } }) end },

        -- ['<Up>'] = { 'select_prev', 'fallback' },
        -- ['<Down>'] = { 'select_next', 'fallback' },
        -- ['<C-space>'] = {
        --   function(cmp)
        --     cmp.show({
        --       providers = {
        --         'snippets'
        --       }
        --     })
        --   end
        -- },
      },
      signature = {
        enabled = true,
      },
      appearance = {
        use_nvim_cmp_as_default = true,
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = { border = "rounded", },
        },
        ghost_text = {
          enabled = true,
        },
        --   menu = {
        --     auto_show = true,
        --     draw = {
        --       treesitter = { "lsp", },
        --     },
        --   },
        --   trigger = {
        --     prefetch_on_insert = true,
        --     blocked_trigger_characters = {},
        --     show_on_blocked_trigger_characters = {},
        --   },
      },
    },
    -- config = function(_, opts)

    -- for server, config in ipairs(opts.servers) do
    --   blink.get_lsp_capabilities(config.capabilities)
    -- end

    -- for _, lsp in ipairs(opts.servers) do
    --   lspconfig[lsp].setup({
    --     on_attach = on_attach,
    --     capabilities = capabilities,
    --     flags = {
    --       debounce_text_changes = 150,
    --     }
    --   })
    -- end
  }
}
