require("core.editor")
require("core.keymaps")
require("core.appearance")
require("core.diagnostic")

require("plugins.packer")
require("plugins.fzf")
require("plugins.lsp")
require("plugins.cmp")
require("plugins.treesitter")

vim.cmd("source ~/dotfiles/unix/config/vimrc")
