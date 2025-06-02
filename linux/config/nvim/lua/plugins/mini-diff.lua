return {
  {
    "echasnovski/mini.diff",
    version = "*",
    event = { "BufRead" },
    keys = {
      { "gh", function() MiniDiff.toggle_overlay() end, desc = "Toggle Diff Hunk", mode = "n" }
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
