return {
  "folke/snacks.nvim",
  version = "*",
  priority = 999,
  keys = {
    {
      "<leader>f",
      function() Snacks.picker.files() end,
      desc = "Open file in workspace",
      noremap = true,
      silent = true,
    },
    {
      "<leader>b",
      function() Snacks.picker.buffers() end,
      desc = "Open buffers",
      noremap = true,
      silent = true,
    },
    {
      "<leader>gd",
      function() Snacks.picker.diagnostics() end,
      desc = "Diagnostics",
      noremap = true,
    },
    {
      "<leader>d",
      function() Snacks.picker.diagnostics_buffer() end,
      desc = "Buffer Diagnostics",
      noremap = true,
    },
    {
      "<leader>lr",
      function() Snacks.picker.lsp_references() end,
      desc = "References",
      noremap = true,
    },
    {
      "<leader>gs",
      function() Snacks.picker.grep() end,
      desc = "Live Grep",
      noremap = true,
    },
    {
      "<leader>gw",
      function() Snacks.picker.grep_word() end,
      desc = "Grep Word",
      noremap = true,
    },
    {
      "<leader>s",
      function() Snacks.picker.spelling() end,
      desc = "Spell Suggestions",
      noremap = true,
    },
    {
      "<leader>q",
      function() Snacks.picker.qflist() end,
      desc = "Quickfix List",
      noremap = true,
    },
    {
      "<leader>r",
      function() Snacks.picker.resume() end,
      desc = "Resume Last Picker",
      noremap = true,
    },
    {
      "gr",
      function() Snacks.picker.lsp_references() end,
      nowait = true,
      desc = "References"
    },
    {
      "gd",
      function() Snacks.picker.lsp_definitions() end,
      desc = "Goto Definition"
    },
  },
  opts = {
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
      formatters = {
        file = {
          truncate = 80,
          filename_first = true
        },
      },
      jump = {
        reuse_win = true
      },
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },

            ["<CR>"] = { { "pick_win", "jump" }, mode = { "n", "i" } },

            ["<c-s>"] = { "edit_split", mode = { "n", "i" } },
            ["<c-v>"] = { "edit_vsplit", mode = { "n", "i" } },
          },
        },
      },
    }
  }
}
