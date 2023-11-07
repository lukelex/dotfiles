pcall(require, "core.editor")
pcall(require, "core.keymaps")
pcall(require, "core.diagnostic")
pcall(require, "core.appearance")

pcall(require, "plugins.packer")
pcall(require, "plugins.telescope")
pcall(require, "plugins.language-server-protocol")
pcall(require, "plugins.cmp")
pcall(require, "plugins.treesitter")
pcall(require, "plugins.lualine")
pcall(require, "plugins.tabby")

vim.cmd("source $DOTFILES/linux/config/nvim/vimrc")
