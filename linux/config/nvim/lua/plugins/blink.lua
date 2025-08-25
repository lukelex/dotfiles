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
      default = function(ctx)
        local success, node = pcall(vim.treesitter.get_node)

        if success and node and vim.tbl_contains({ 'comment', 'line_comment', 'block_comment' }, node:type()) then
          return { 'buffer' }
        else
          return { 'snippets', 'lsp', 'path' }
        end
      end,
      providers = {
        lsp = {
          async = true,    -- Whether we should show the completions before this provider returns, without waiting for it
          timeout_ms = 250 -- How long to wait for the provider to return before showing completions and treating it as asynchronous
        }
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
        auto_show = true,
        draw = {
          treesitter = { "lsp" },
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
        },
      },
    },
  },
}
