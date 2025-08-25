return {
  "folke/snacks.nvim",
  version = "*",
  priority = 999,
  keys = {
    {
      "<leader>f",
      "<cmd>lua Snacks.picker.files()<CR>",
      desc = "Open file in workspace",
      noremap = true,
      silent = true,
    },
    {
      "<leader>b",
      "<cmd>lua Snacks.picker.buffers()<CR>",
      desc = "Open buffers",
      noremap = true,
      silent = true,
    },
    {
      "<leader>gd",
      "<cmd>lua Snacks.picker.diagnostics()<CR>",
      desc = "Diagnostics",
      noremap = true,
    },
    {
      "<leader>d",
      "<cmd>lua Snacks.picker.diagnostics_buffer()<CR>",
      desc = "Buffer Diagnostics",
      noremap = true,
    },
    {
      "<leader>lr",
      "<cmd>lua Snacks.picker.lsp_references()<CR>",
      desc = "References",
      noremap = true,
    },
    {
      "<leader>gs",
      "<cmd>lua Snacks.picker.grep()<CR>",
      desc = "Live Grep",
      noremap = true,
    },
    {
      "<leader>gw",
      "<cmd>lua Snacks.picker.grep_word()<CR>",
      desc = "Grep Word",
      noremap = true,
    },
    {
      "<leader>s",
      "<cmd>lua Snacks.picker.spelling()<CR>",
      desc = "Spell Suggestions",
      noremap = true,
    },
    {
      "<leader>q",
      "<cmd>lua Snacks.picker.qflist()<CR>",
      desc = "Quickfix List",
      noremap = true,
    },
    {
      "<leader>r",
      "<cmd>lua Snacks.picker.resume()<CR>",
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
