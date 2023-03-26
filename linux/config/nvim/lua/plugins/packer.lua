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
  use "wbthomason/packer.nvim"

  -- Editor improvements
  use "mbbill/undotree"
  use "nvim-treesitter/nvim-treesitter"
  use "DataWraith/auto_mkdir"
  use "danro/rename.vim"
  use "henrik/vim-indexed-search"
  use "schickling/vim-bufonly"
  use "mileszs/ack.vim"
  use "tpope/vim-commentary"
  use "tpope/vim-fugitive"
  use "airblade/vim-gitgutter"
  use "tpope/vim-repeat"
  use "tpope/vim-surround"
  use "tpope/vim-endwise"
  use "Raimondi/delimitMate"
  use {
    "junegunn/fzf.vim",
    "junegunn/fzf", run = function() vim.fn["fzf#install()"](0) end
  }
  use "itchyny/lightline.vim"

  -- Language improvements
  use "editorconfig/editorconfig-vim"
  use "terrastruct/d2-vim"
  use {
    "kana/vim-textobj-user",
    "nelstrom/vim-textobj-rubyblock"
  }
  use "fladson/vim-kitty"
  use "ron-rs/ron.vim"
  use "elkowar/yuck.vim"
  use "baskerville/vim-sxhkdrc"

  -- Language Server Protocol
  use {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",
  }
  use {
    "hrsh7th/nvim-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "rafamadriz/friendly-snippets"
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    packer.sync()
  end
end)
