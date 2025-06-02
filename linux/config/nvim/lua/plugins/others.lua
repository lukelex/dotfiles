return {
  {
    -- Editor improvements
    "DataWraith/auto_mkdir",
    { "danro/rename.vim",                 event = { "BufRead" } },
    { "tpope/vim-commentary",             event = { "BufRead" } },
    { "tpope/vim-fugitive",               event = { "BufRead" } },
    { "tpope/vim-repeat",                 event = { "BufRead" } },
    { "tpope/vim-surround",               event = { "BufRead" } },
    { "schickling/vim-bufonly",           event = { "BufRead" } },
    { "mfussenegger/nvim-lint",           event = { "BufRead" } },

    -- Language improvements
    { "ron-rs/ron.vim",                   event = { "BufRead" } },
    { "baskerville/vim-sxhkdrc",          event = { "BufRead" } },
    { "kmonad/kmonad-vim",                event = { "BufRead" } },
    { "slint-ui/vim-slint",               event = { "BufRead" } },
    { "luizribeiro/vim-cooklang",         event = { "BufRead" } },
    { "mustache/vim-mustache-handlebars", event = { "BufRead" } },
    { "isobit/vim-caddyfile",             event = { "BufRead" } },
  }
}
