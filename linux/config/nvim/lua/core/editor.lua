vim.g.loaded_netrw = 1

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

-- local M = {}

local function ensure_directory_exists(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function path_to_test(path)
  return path
      :gsub("/backend/app/", "/backend/spec/")
      :gsub("%.rb$", "_spec.rb")
end

local function path_to_source(path)
  return path
      :gsub("/backend/spec/", "/backend/app/")
      :gsub("_spec%.rb$", ".rb")
end

local function find_window_with_file(target_path)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bufname = vim.api.nvim_buf_get_name(buf)
    if vim.fn.fnamemodify(bufname, ":p") == vim.fn.fnamemodify(target_path, ":p") then
      return win
    end
  end
  return nil
end

function ToggleTestFile()
  local filepath = vim.fn.expand("%:p")
  local target_path

  if filepath:match("/backend/app/") then
    target_path = path_to_test(filepath)
  elseif filepath:match("/backend/spec/") then
    target_path = path_to_source(filepath)
  else
    print("Not in app/ or spec/ file.")
    return
  end

  ensure_directory_exists(target_path)

  if vim.fn.filereadable(target_path) == 0 then
    local file = io.open(target_path, "w")
    if file then
      file:write("-- RSpec test file\n")
      file:close()
      print("Created file: " .. target_path)
    else
      print("Failed to create file: " .. target_path)
      return
    end
  end

  local existing_win = find_window_with_file(target_path)
  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
  else
    vim.cmd("vsplit " .. vim.fn.fnameescape(target_path))
  end
end

-- return M

vim.cmd('command! ToggleTestFile lua OpenRubyTestFile()')
vim.keymap.set("n", "<Space>t", function()
  -- require("user.test_nav").open_test_file()
  ToggleTestFile()
end, { desc = "Open test file in vertical split" })
