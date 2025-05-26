local function bootstrap_pckr()
  local pckr_path = vim.fn.stdpath("data") .. "/pckr/pckr.nvim"

  if not (vim.uv or vim.loop).fs_stat(pckr_path) then
    vim.fn.system({
      'git',
      'clone',
      "--filter=blob:none",
      'https://github.com/lewis6991/pckr.nvim',
      pckr_path
    })
  end

  vim.opt.rtp:prepend(pckr_path)
end

bootstrap_pckr()

local group = vim.api.nvim_create_augroup("packer_user_config", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  command = "source <afile> | Pckr sync",
  pattern = "packer.lua", -- the name of your plugins file
  group = group,
})

require('pckr').add {
  "wbthomason/packer.nvim",

  -- Editor improvements
  "mbbill/undotree",
  "nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    after = "nvim-treesitter",
    requires = "nvim-treesitter/nvim-treesitter",
  },
  "nvim-treesitter/playground",
  "DataWraith/auto_mkdir",
  "danro/rename.vim",
  "schickling/vim-bufonly",
  "tpope/vim-commentary",
  "tpope/vim-fugitive",
  "tpope/vim-repeat",
  "tpope/vim-surround",
  {
    "RRethy/nvim-treesitter-endwise",
    after = "nvim-treesitter",
    requires = "nvim-treesitter/nvim-treesitter",
  },
  "echasnovski/mini.cursorword",
  "echasnovski/mini.diff",
  "echasnovski/mini.indentscope",
  "echasnovski/mini.pairs",
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    run = "make"
  },
  {
    "nvim-telescope/telescope.nvim",
    requires = {
      {
        "nvim-lua/plenary.nvim",
        "BurntSushi/ripgrep",
      }
    }
  },
  "nanozuki/tabby.nvim",

  -- Appearance
  "norcalli/nvim-colorizer.lua",
  {
    "lukelex/railscasts.nvim",
    requires = { "rktjmp/lush.nvim" }
  },
  {
    "nvim-lualine/lualine.nvim",
    requires = { "nvim-tree/nvim-web-devicons" }
  },

  -- Language improvements
  "terrastruct/d2-vim",
  {
    "kana/vim-textobj-user",
    "nelstrom/vim-textobj-rubyblock"
  },
  "ron-rs/ron.vim",
  "elkowar/yuck.vim",
  "baskerville/vim-sxhkdrc",
  "kmonad/kmonad-vim",
  "slint-ui/vim-slint",
  "luizribeiro/vim-cooklang",
  "mustache/vim-mustache-handlebars",
  "isobit/vim-caddyfile",
  {
    "luckasRanarison/tree-sitter-hyprlang",
    requires = { "nvim-treesitter/nvim-treesitter" },
  },
  {
    "MeanderingProgrammer/markdown.nvim",
    after = { "nvim-treesitter" },
    requires = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
      opt = true
    },
    config = function()
      require("render-markdown").setup()
    end
  },

  -- Language Server Protocol
  {
    "neovim/nvim-lspconfig",
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "j-hui/fidget.nvim"
  },
  {
    "hrsh7th/nvim-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-nvim-lua",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "rafamadriz/friendly-snippets",
    "onsails/lspkind.nvim",
  },

  -- Code Linting & Formatting
  { "stevearc/conform.nvim" },
  { "mfussenegger/nvim-lint" },
}
