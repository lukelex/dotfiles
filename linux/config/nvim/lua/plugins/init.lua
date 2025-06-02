return {
  {
    -- Editor improvements
    "mbbill/undotree",
    "DataWraith/auto_mkdir",
    "danro/rename.vim",
    "schickling/vim-bufonly",
    "tpope/vim-commentary",
    "tpope/vim-fugitive",
    "tpope/vim-repeat",
    "tpope/vim-surround",

    "echasnovski/mini.cursorword",
    "echasnovski/mini.indentscope",
    {
      "echasnovski/mini.pairs",
      config = function()
        require("mini.pairs").setup()
      end
    },

    -- Appearance
    "norcalli/nvim-colorizer.lua",
    { "echasnovski/mini.notify", version = "*" },

    { "mfussenegger/nvim-lint" },

    -- Language improvements
    "ron-rs/ron.vim",
    "baskerville/vim-sxhkdrc",
    "kmonad/kmonad-vim",
    "slint-ui/vim-slint",
    "luizribeiro/vim-cooklang",
    "mustache/vim-mustache-handlebars",
    "isobit/vim-caddyfile",
  }
}
