require("core.editor")
require("core.keymaps")
require("core.appearance")
require("core.diagnostic")

require("plugins.packer")
require("plugins.telescope")
require("plugins.lsp")
require("plugins.cmp")
require("plugins.treesitter")

vim.cmd("source $HOME/dotfiles/unix/config/vimrc")
