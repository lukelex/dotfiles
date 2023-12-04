local cmp = require("cmp")
local snippets = require("luasnip")

require("luasnip.loaders.from_vscode").lazy_load()

local function check_backspace()
  local col = vim.fn.col(".") - 1
  return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
end

cmp.setup({
  snippet = {
    expand = function(args)
      snippets.lsp_expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
    ["<C-d>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function (fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif snippets.expandable() then
        snippets.expand()
      elseif snippets.expand_or_jumpable() then
        snippets.expand_or_jump()
      elseif check_backspace() then
        fallback()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function (fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif snippets.jumpable(-1) then
        snippets.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  formatting = {
    fields = { "abbr", "menu" },
    format = function(entry, vim_item)
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        luasnip = "[Snippet]",
        buffer = "[Buffer]",
        path = "[Path]",
      })[entry.source.name]
      return vim_item
    end
  },
  sources = cmp.config.sources({
    { name = "nvim_lsp", keyword_length = 2 },
    { name = "luasnip", keyword_length = 2 },
    { name = "buffer", keyword_length = 2 },
    { name = "path" }
  }, {
    { name = "buffer" },
  }),
  confirm_opts = {
    behavior = cmp.ConfirmBehavior.Replace,
    select = false
  },
})
