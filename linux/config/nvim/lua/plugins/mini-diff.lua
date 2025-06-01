return {
  {
    "echasnovski/mini.diff",
    keys = {
      { "gh", ":lua MiniDiff.toggle_overlay()<CR>", desc = "Toggle Diff Hunk" }
    },
    config = function()
      require("mini.diff").config()
      -- vim.map("gh", ":lua MiniDiff.toggle_overlay()<CR>")
    end
  },
}
