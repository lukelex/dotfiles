return {
  "saghen/blink.cmp",
  lazy = false,
  event = { "InsertEnter" },
  version = "1.*",
  dependencies = {
    "neovim/nvim-lspconfig",
  },
  opts = {
    keymap = {
      preset = "enter",

      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<Tab>"] = {
        function(cmp)
          if not cmp.snippet_active() then
            return cmp.select_and_accept()
          end
        end,
        "select_next",
        "fallback"
      },

      ["<C-space>"] = { function(cmp) cmp.show() end },
    },
    fuzzy = {
      implementation = "prefer_rust",
      sorts = {
        "exact"
      }
    },
    signature = {
      enabled = true,
    },
    appearance = {
      use_nvim_cmp_as_default = true,
    },
    snippets = {
      enabled = true,
    },
    sources = {
      min_keyword_length = 3,
      default = { "lsp", "path", "snippets", "buffer" }
    },
    completion = {
      list = { selection = { preselect = false } },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded", },
      },
    },
  },
}
