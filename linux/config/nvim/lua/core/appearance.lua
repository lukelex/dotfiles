vim.opt.guifont = "Hack:h17"

vim.diagnostic.config({ float = { border = "rounded" } })

vim.opt.background = "dark" -- colorschemes that can be light or dark will be made dark
vim.opt.laststatus = 2      -- always display status line
vim.opt.wrap = false        -- no wrapping lines
vim.cmd("set noshowmode")   -- Hide current mode on last line

-- cursor settings
vim.opt.ruler = true      -- show the cursor position all the time
vim.opt.cursorline = true -- show cursor line

-- search tweaks
vim.opt.hlsearch = true     -- highlight search results
vim.opt.incsearch = true    -- show search results while typing
vim.cmd("set shortmess-=S") -- show search count message

-- Make it obvious where 65 characters is on text files
vim.cmd("autocmd BufRead,BufNewFile *.md set textwidth=65")
vim.cmd("set colorcolumn=+1")

vim.opt.signcolumn = "yes" -- always show sign column so that text doesn't shift

vim.o.winborder = "rounded"
