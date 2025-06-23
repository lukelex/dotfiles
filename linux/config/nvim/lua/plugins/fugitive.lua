return {
  "tpope/vim-fugitive",
  event = { "BufRead" },
  keys = {
    { "gb", ":Git blame<CR>", desc = "Toggle File Diff", mode = "n" }
  },
}
