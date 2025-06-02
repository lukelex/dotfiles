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
        preset = "enter",

        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },

        ['<C-space>'] = { function(cmp) cmp.show() end },

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
      fuzzy = {
        implementation = "prefer_rust"
      },
      signature = {
        enabled = true,
      },
      appearance = {
        use_nvim_cmp_as_default = true,
      },
      completion = {
        list = { selection = { preselect = false } },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = { border = "rounded", },
        },
        ghost_text = {
          enabled = true,
        },
      },
    },
  }
}
