return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {},
  config = function()
    require('noice').setup {
      -- lsp = {
      --   enable = false
      -- },
      presets = {
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      routes = {
        { filter = { find = "lines" }, skip = true }, -- skip yank and paste
        {
          filter = {
            event = "lsp",
            kind = "progress",
            cond = function(message)
              local client = vim.tbl_get(message.opts, "progress", "client")
              return client == "solargraph"
            end,
          },
          opts = { skip = true },
        },
      },
      views = {
        cmdline_popup = {
          position = {
            row = 5,
            col = "50%",
          },
          size = {
            width = 60,
            height = "auto",
          },
        },
      },
      popupmenu = {
        relative = "editor",
        position = {
          row = 8,
          col = "50%",
        },
        size = {
          width = 60,
          height = 10,
        },
        border = {
          style = "rounded",
          padding = { 0, 1 },
        },
        win_options = {
          winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
        },
      },
    }
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  }
}
