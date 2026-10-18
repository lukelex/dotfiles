return {
  "folke/snacks.nvim",
  version = "*",
  priority = 999,
  opts = {
    -- Keep the fast startup path for opening files; FzfLua handles all picker
    -- workflows and vim.ui.select prompts.
    quickfile = { enabled = true },
  },
}
