local opt = vim.opt
local global = vim.g

global.shell = "bash"

-- backup files
vim.cmd("set noswapfile")

-- Tweaks for file browsing
global.netrw_banner = 0       -- disable annoying banner
global.netrw_browse_split = 0 -- open in prior window
global.netrw_altv = 1         -- open split to the right
global.netrw_liststyle = 3    -- tree view

global.editorconfig = true

opt.backspace = "2"
opt.showcmd = true -- display incomplete commands
opt.mouse = "a"    -- enable mouse events in all modes

-- master fucking undo
opt.undofile = true
opt.undodir = string.format("%s/.vim-cache/undodir", vim.env.HOME)

opt.backup = true
opt.backupdir = string.format("%s/.vim-cache/backup", vim.env.HOME)

-- use system clipboard as default register
opt.clipboard:append("unnamedplus")

-- autoread files that were changed outside of vim
opt.autoread = true

-- line number
opt.number = true
opt.relativenumber = true

-- search settings
vim.cmd("setlocal ignorecase") -- ignore case when searching
vim.cmd("setlocal smartcase")  -- when searching try to be smart about cases

-- use 2 spaces instead of tabs
opt.expandtab = true
opt.smarttab = true
opt.tabstop = 2
opt.shiftwidth = 2

-- use an already open window if possible
opt.switchbuf = "useopen"

-- use natural screen spliting
opt.splitbelow = true
opt.splitright = true

opt.ttyfast = true

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

-- Optionally, map this function to a Vim command for easy access
vim.cmd('command! OpenConflicts lua OpenGitConflicts()')

vim.opt.sessionoptions = 'curdir,folds,globals,help,tabpages,terminal,winsize'
