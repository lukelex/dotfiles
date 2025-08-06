return {
  "saghen/blink.cmp",
  lazy = false,
  event = { "BufRead" },
  version = "1.*",
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
    sources = {
      min_keyword_length = 3,
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        lsp = { fallbacks = {} }
      }
    },
    cmdline = { enabled = false },
    completion = {
      list = { selection = { preselect = false } },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded", },
      },
      menu = {
        draw = {
          treesitter = { "lsp" },
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
        },
      },
    },
  },
}
