require("nvim-treesitter.configs").setup {
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    disable = { "ruby" },
    additional_vim_regex_highlighting = false,
  },
}
