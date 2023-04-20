vim.g.shell = "bash"

-- Tweaks for file browsing
vim.g.netrw_banner = 0 -- disable annoying banner
vim.g.netrw_browse_split = 4 -- open in prior window
vim.g.netrw_altv = 1 -- open split to the right
vim.g.netrw_liststyle = 3 -- tree view

vim.cmd("set noshowmode") -- Hide current mode
vim.cmd("set nowrap") -- avoid line wrapping
vim.opt.laststatus = 2 -- always display status line
vim.opt.backspace = "2"
vim.opt.ruler = true -- show the cursor position all the time
vim.opt.showcmd = true -- display incomplete commands
vim.opt.mouse = "a" -- enable mouse events in all modes
vim.opt.hlsearch = true -- highlight search results
vim.opt.incsearch = true -- show search results while typing

-- master fucking undo
vim.opt.undofile = true
vim.opt.undodir = string.format("%s/.cache/undodir", vim.env.HOME)

vim.opt.backup = true
vim.opt.backupdir = string.format("%s/.config/nvim/backup", vim.env.HOME)

-- universal clipboard
vim.opt.clipboard = "unnamedplus"

-- autoread files that were changed outside of vim
vim.opt.autoread = true

vim.opt.cursorline = true -- show cursor line
vim.opt.number = true
vim.opt.relativenumber = true

-- use 2 spaces instead of tabs
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

-- use an already open window if possible
vim.opt.switchbuf = "useopen"

-- use natural screen spliting
vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.ttyfast = true
-- vim.opt.ttyscroll = 3
-- vim.opt.lazyredraw = true
