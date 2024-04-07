vim.opt.signcolumn = "yes" -- always show sign column so that text doesn't shift

require("gitsigns").setup {
  signs = {
    add          = { text = "│" },
    change       = { text = "│" },
    delete       = { text = "_" },
    topdelete    = { text = "‾" },
    changedelete = { text = "~" },
    untracked    = { text = "┆" },
  },
}

vim.keymap.set("n", "gh", ":Gitsigns preview_hunk<CR>", {})
