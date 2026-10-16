return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {},
  config = function()
    require('noice').setup {
      lsp = {
        hover = {
          silent = true,
        },
      },
      presets = {
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      routes = {
        { filter = { event = "msg_show", kind = "yank" }, opts = { skip = true } },
        {
          filter = { event = "msg_show", kind = "", find = "^%d+ more lines$" },
          opts = { skip = true },
        },
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
            row = "10%",
            col = "50%",
          },
          size = {
            width = "80%",
            height = "auto",
          },
        },
        cmdline_popupmenu = {
          -- Follow the command popup instead of assuming it is on row 5.
          position = "auto",
          size = { width = "80%", height = "25%" },
          border = { style = "rounded", padding = { 0, 1 } },
          win_options = {
            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
          },
        },
      },
    }
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  }
}
