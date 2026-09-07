return {
  "dmtrKovalenko/fff.nvim",
  lazy = false,
  enabled = false,
  build = "cargo build --release",
  keys = {
    {
      "<leader>f",
      function()
        require("fff").find_files()
      end,
      desc = "Open file in workspace",
      -- noremap = true,
      -- silent = true,
    },
    {
      "<leader>b",
      function()
        require("fff").find_files()
      end,
      desc = "Open buffers",
      noremap = true,
      silent = true,
    }
  },
  opts = {
    prompt = "> ",
    keymaps = {
      move_up = { "<Up>", "<C-k>" },
      move_down = { "<Down>", "<C-j>" },
    }
  }
}
