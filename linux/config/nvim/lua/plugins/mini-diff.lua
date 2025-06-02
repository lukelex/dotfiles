return {
  {
    "echasnovski/mini.diff",
    version = "*",
    event = { "BufRead" },
    keys = {
      { "gh", ":lua MiniDiff.toggle_overlay()<CR>", desc = "Toggle Diff Hunk" }
    },
    config = function()
      require("mini.diff").setup({
        mappings = {
          apply = "gha",
        }
      })
    end
  },
}
