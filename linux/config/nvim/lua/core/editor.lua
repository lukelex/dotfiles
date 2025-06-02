local global = vim.g

-- Disable Vi compatibility mode
vim.g.compatible = false

vim.g.shell = "bash"

-- backup files
vim.cmd("set noswapfile")

-- Tweaks for file browsing
vim.g.netrw_banner = 0       -- disable annoying banner
vim.g.netrw_browse_split = 0 -- open in prior window
vim.g.netrw_altv = 1         -- open split to the right
vim.g.netrw_liststyle = 3    -- tree view

vim.g.editorconfig = true

vim.opt.backspace = "2"
vim.opt.showcmd = true -- display incomplete commands
vim.opt.mouse = "a"    -- enable mouse events in all modes

-- master fucking undo
vim.opt.undofile = true
vim.opt.undodir = string.format("%s/.vim-cache/undodir", vim.env.HOME)

vim.opt.backup = true
vim.opt.backupdir = string.format("%s/.vim-cache/backup", vim.env.HOME)

-- use system clipboard as default register
vim.opt.clipboard:append("unnamedplus")

-- autoread files that were changed outside of vim
vim.opt.autoread = true

-- line number
vim.opt.number = true
vim.opt.relativenumber = true

-- search settings
vim.cmd("setlocal ignorecase") -- ignore case when searching
vim.cmd("setlocal smartcase")  -- when searching try to be smart about cases

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

vim.filetype.add({
  extension = {
    es6 = 'javascript',
    jbuilder = 'ruby',
    json_schema = 'json',
    rasi = 'rasi',
    service = 'systemd',
  },
  filename = {
    ['Guardfile'] = 'ruby',
  },
})

vim.diagnostic.config({
  virtual_text = false,
  signs = true,
})

vim.cmd('command! PrettyPrintJSON %!python -m json.tool')
function OpenGitConflicts()
  local handle = io.popen('git diff --name-only --diff-filter=U')
  local result = handle:read("*a")
  handle:close()

  -- Split the result into lines (file paths)
  local files = {}
  for file in result:gmatch("[^\r\n]+") do
    table.insert(files, file)
  end

  -- Open each file in a new buffer
  if next(files) ~= nil then
    for _, file in ipairs(files) do
      vim.cmd('edit ' .. file)
    end
  else
    print("No conflicts found.")
  end
end

vim.cmd('command! OpenConflicts lua OpenGitConflicts()')

vim.opt.sessionoptions = 'curdir,folds,globals,help,tabpages,terminal,winsize'
