pcall(require, "core.editor")
pcall(require, "core.keymaps")
pcall(require, "core.appearance")

pcall(require, "plugins.packer")
pcall(require, "plugins.telescope")
pcall(require, "plugins.language-server-protocol")
pcall(require, "plugins.formatter")
pcall(require, "plugins.completion")
pcall(require, "plugins.treesitter")
pcall(require, "plugins.lualine")
pcall(require, "plugins.tabby")
pcall(require, "plugins.gitsigns")
pcall(require, "plugins.others")

vim.cmd("source $DOTFILES/linux/config/nvim/vimrc")
