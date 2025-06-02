return {
  "folke/snacks.nvim",
  version = "*",
  priority = 1000,
  keys = {
    {
      "<leader>f",
      "<cmd>lua Snacks.picker.files()<CR>",
      mode = { "n" },
      desc = "Open file in workspace",
      noremap = true,
      silent = true,
    },
    {
      "<leader>b",
      "<cmd>lua Snacks.picker.buffers()<CR>",
      mode = { "n" },
      desc = "Open buffers",
      noremap = true,
      silent = true,
    },
    {
      "<leader>lr",
      "<cmd>lua Snacks.picker.lsp_references()<CR>",
      mode = { "n" },
      desc = "References",
      noremap = true,
    },
    {
      "<leader>gs",
      "<cmd>lua Snacks.picker.grep()<CR>",
      mode = { "n" },
      desc = "Live Grep",
      noremap = true,
    },
    {
      "<leader>gw",
      "<cmd>lua Snacks.picker.grep_word()<CR>",
      mode = { "n" },
      desc = "Grep Word",
      noremap = true,
    },
    {
      "<leader>s",
      function()
        Snacks.picker.spelling({
          finder = "vim_spelling",
          format = "text",
          layout = { preset = "dropdown" },
          confirm = "item_action",
        })
      end,
      mode = { "n" },
      desc = "Spell Suggestions",
      noremap = true,
    },
    {
      "<leader>q",
      "<cmd>lua Snacks.picker.qflist()<CR>",
      mode = { "n" },
      desc = "Quickfix List",
      noremap = true,
    },
    {
      "<leader>r",
      "<cmd>lua Snacks.picker.resume()<CR>",
      mode = { "n" },
      desc = "Resume Last Picker",
      noremap = true,
    },
  },
  opts = {
    notifier = {
      enabled = true,
      timeout = 5000, -- default timeout in ms
    },
    quickfile = { enabled = true },
    picker = {
      sources = {
        files = {
          hidden = true,
        },
      },
      layout = {
        layout = {
          width = 0.5,
          min_width = 80,
          height = 0.8,
          min_height = 30,
          box = "vertical",
          border = "rounded",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input",   height = 1,          border = "bottom" },
          { win = "list",    border = "none" },
          { win = "preview", title = "{preview}", height = 0.7,     border = "top" },
        },
      },
      ui_select = true,
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },
          },
        },
      },
    }
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    _G.lsp_notify_tracker = _G.lsp_notify_tracker or {}

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local buf = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        local key = buf .. ":" .. client.name
        if _G.lsp_notify_tracker[key] then
          return
        end
        _G.lsp_notify_tracker[key] = true

        vim.notify(
          string.format("'%s' attached to buffer", client.name),
          "info",
          { title = string.format("LSP Attach (%d)", buf) }
        )
      end,
    })
  end
}
