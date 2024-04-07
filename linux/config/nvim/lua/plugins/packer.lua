local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

local group = vim.api.nvim_create_augroup("packer_user_config", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  command = "source <afile> | PackerSync",
  pattern = "packer.lua", -- the name of your plugins file
  group = group,
})

local packer = require("packer")

return packer.startup(function(use)
  use("wbthomason/packer.nvim")

  -- Editor improvements
  use("mbbill/undotree")
  use("nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" })
  use({
    "nvim-treesitter/nvim-treesitter-textobjects",
    after = "nvim-treesitter",
    requires = "nvim-treesitter/nvim-treesitter",
  })
  use('nvim-treesitter/playground')
  use("DataWraith/auto_mkdir")
  use("danro/rename.vim")
  use("schickling/vim-bufonly")
  use("tpope/vim-commentary")
  use("tpope/vim-fugitive")
  use("tpope/vim-repeat")
  use("tpope/vim-surround")
  use("lewis6991/gitsigns.nvim")
  use({
    "RRethy/nvim-treesitter-endwise",
    after = "nvim-treesitter",
    requires = "nvim-treesitter/nvim-treesitter",
  })
  use("Raimondi/delimitMate")
  use({
    "nvim-telescope/telescope-fzf-native.nvim",
    run = "make"
  })
  use({
    "nvim-telescope/telescope.nvim",
    requires = {
      {
        "nvim-lua/plenary.nvim",
        "BurntSushi/ripgrep",
      }
    }
  })
  use("nanozuki/tabby.nvim")

  -- Appearance
  use("lukas-reineke/indent-blankline.nvim")
  use("norcalli/nvim-colorizer.lua")
  use({
    "lukelex/railscasts.nvim",
    requires = { "rktjmp/lush.nvim" }
  })
  use({
    "nvim-lualine/lualine.nvim",
    requires = { "nvim-tree/nvim-web-devicons" }
  })

  -- Language improvements
  use("terrastruct/d2-vim")
  use({
    "kana/vim-textobj-user",
    "nelstrom/vim-textobj-rubyblock"
  })
  use("ron-rs/ron.vim")
  use("elkowar/yuck.vim")
  use("baskerville/vim-sxhkdrc")
  use("kmonad/kmonad-vim")
  use({
    "luckasRanarison/tree-sitter-hyprlang",
    requires = { "nvim-treesitter/nvim-treesitter" },
  })

  -- Language Server Protocol
  use({
    "neovim/nvim-lspconfig",
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "j-hui/fidget.nvim"
  })
  use({
    "hrsh7th/nvim-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-nvim-lua",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "rafamadriz/friendly-snippets"
  })

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    packer.sync()
  end
end)
