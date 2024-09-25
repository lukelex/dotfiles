local opt = vim.opt -- for conciseness

opt.guifont = "Hack:h17"

vim.diagnostic.config({ float = { border = "rounded" } })

opt.background = "dark"   -- colorschemes that can be light or dark will be made dark
opt.laststatus = 2        -- always display status line
opt.wrap = false          -- no wrapping lines
vim.cmd("set noshowmode") -- Hide current mode

-- cursor settings
opt.ruler = true      -- show the cursor position all the time
opt.cursorline = true -- show cursor line

-- search tweaks
opt.hlsearch = true         -- highlight search results
opt.incsearch = true        -- show search results while typing
vim.cmd("set shortmess-=S") -- show search count message

-- Make it obvious where 65 characters is on text files
vim.cmd("autocmd BufRead,BufNewFile *.md set textwidth=65")
vim.cmd("set colorcolumn=+1")

opt.signcolumn = "yes" -- always show sign column so that text doesn't shift

vim.cmd.colorscheme "railscasts"
