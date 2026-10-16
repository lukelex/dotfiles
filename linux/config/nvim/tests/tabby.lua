local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local plugin = vim.env.TABBY_NVIM_PATH or (vim.fn.stdpath('data') .. '/lazy/tabby.nvim')
assert(vim.fn.isdirectory(plugin) == 1, 'Install Tabby or set TABBY_NVIM_PATH')
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(plugin)
vim.cmd('runtime plugin/tabby.vim')
dofile(root .. '/lua/plugins/tabby.lua').config()
local tl = require('tabby.tabline')
local names = require('tabby.feature.tab_name')
local checks = 0

local function render(expect_current)
  local node = tl.cfg.fn(require('tabby.feature.lines').get_line())
  local visible = {}
  for _, child in ipairs(node) do
    if type(child) == 'table' and child.click then
      visible[#visible + 1] = vim.api.nvim_tabpage_get_number(child.click[2])
    end
  end
  if expect_current then
    assert(vim.tbl_contains(visible, vim.fn.tabpagenr()), 'active tab hidden')
  end
  local evaluated = vim.api.nvim_eval_statusline(tl.render(), { use_tabline = true, maxwidth = 100000 })
  assert(evaluated.width <= vim.o.columns, 'overflow: ' .. evaluated.width .. '/' .. vim.o.columns)
  checks = checks + 1
  return visible, evaluated.str
end

local function mapping(desc)
  for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
    if map.desc == desc then map.callback(); return end
  end
  error('missing mapping ' .. desc)
end

for i = 1, 20 do
  if i > 1 then vim.cmd.tabnew() end
  names.set(0, i == 1 and string.rep('long', 16) or ('tab' .. i))
end
for _, width in ipairs({ 80, 40, 20, 12, 160, 300 }) do
  vim.o.columns = width
  for i = 1, 20 do
    vim.cmd('normal! ' .. i .. 'gt')
    render(true)
  end
  for i = 20, 1, -1 do
    vim.cmd('normal! ' .. i .. 'gt')
    render(true)
  end
end
vim.o.columns = 80
vim.cmd('tabnext 1')
render(true)
for _ = 1, 8 do _G.DotfilesTablineScroll(2, 1, 'l') end
assert(render(false)[1] == 9, 'manual scrolling snapped back')
assert(vim.fn.tabpagenr() == 1, 'scroll changed selected tab')
assert(render(false)[1] == 9, 'redraw reset scrolling')
_G.DotfilesTablineScroll(1, 1, 'l')
assert(render(false)[1] == 8, 'left scroll failed')
vim.cmd('normal! 2gt')
render(true)
names.set(0, '界界界界界界界界界界界界界界界界界界界界界界')
render(true)
names.set(0, '100% done %T %X')
local _, text = render(true)
assert(text:find('100%% done %%T %%X'), 'percent escapes broken')
vim.cmd('tabmove 18')
render(true)
vim.o.columns = 20
local _, compact_text = render(true)
assert(compact_text:find('/'), 'compact label lost name prefix')
assert(compact_text:find('100%%'), 'compact label lost workspace name')
vim.o.columns = 80
vim.cmd('tabnext 1')
local before = render(true)
mapping('Page tabline right')
local after = render(false)
assert(after[1] == before[#before] + 1, 'forward page did not advance a viewport')
mapping('Page tabline left')
assert(render(false)[1] == 1, 'backward page did not return to start')
for _ = 1, 100 do mapping('Scroll tabline right') end
local ending = render(false)
assert(ending[#ending] == #vim.api.nvim_list_tabpages(), 'end not visible')
assert(#ending > 1, 'end viewport unnecessarily empty')
mapping('Scroll tabline right')
assert(vim.deep_equal(ending, render(false)), 'scroll went beyond last viewport')

-- Use an interior viewport so end backfilling does not affect anchoring.
vim.cmd('tabnext 2')
render(true)
for _ = 1, 6 do mapping('Scroll tabline right') end
local anchored = render(false)
local anchor_id = vim.api.nvim_list_tabpages()[anchored[1]]
vim.cmd('1tabclose')
local after_close = render(false)
assert(vim.api.nvim_list_tabpages()[after_close[1]] == anchor_id, 'closing preceding tab moved anchor')
local successor = vim.api.nvim_list_tabpages()[after_close[1] + 1]
vim.cmd(after_close[1] .. 'tabclose')
local after_anchor_close = render(false)
assert(vim.api.nvim_list_tabpages()[after_anchor_close[1]] == successor, 'closed anchor did not select successor')
vim.cmd('tabmove 0')
assert(vim.api.nvim_list_tabpages()[render(false)[1]] == successor, 'reordering preceding tab moved anchor')
vim.cmd('tabnext 5')
render(true)
for _, width in ipairs({ 12, 20, 40, 80, 160, 300 }) do
  vim.o.columns = width
  render(true)
end

-- Capture the UI boundary; exercise real tab selection and the real renderer.
local original_select = vim.ui.select
local items, options, choose
vim.ui.select = function(list, opts, callback)
  items, options, choose = list, opts, callback
end
local function snapshot()
  local result = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local windows = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      windows[win] = vim.api.nvim_win_get_buf(win)
    end
    result[tab] = windows
  end
  return result
end
vim.o.columns = 80
vim.cmd('tabnext 1')
vim.cmd('vsplit')
render(true)
mapping('Find tab')
assert(#items == #vim.api.nvim_list_tabpages(), 'picker omitted hidden tabs')
assert(options.format_item(items[1]):find('1/'), 'picker omitted number')
assert(options.format_item(items[1]):find('(current)', 1, true), 'picker omitted current marker')
local topology = snapshot()
local current = vim.api.nvim_get_current_tabpage()
choose(nil)
assert(vim.api.nvim_get_current_tabpage() == current, 'cancel changed tab')
mapping('Find tab')
local selected = items[#items]
assert(not vim.tbl_contains(render(true), selected.number), 'test target should be hidden')
choose(selected)
assert(vim.api.nvim_get_current_tabpage() == selected.tab, 'picker selected wrong tab')
assert(vim.deep_equal(topology, snapshot()), 'picker changed workspace windows/buffers')
render(true)

-- A current tab hidden by manual scrolling must also be revealed on selection.
for _ = 1, 100 do mapping('Scroll tabline left') end
assert(not vim.tbl_contains(render(false), vim.fn.tabpagenr()), 'current tab should be hidden')
mapping('Find tab')
for _, item in ipairs(items) do
  if item.current then choose(item); break end
end
render(true)

mapping('Find tab')
selected = items[2]
vim.cmd('tabmove 0')
choose(selected)
assert(vim.api.nvim_get_current_tabpage() == selected.tab, 'picker used stale ordinal')
render(true)
mapping('Find tab')
selected = items[#items]
vim.cmd(selected.number .. 'tabclose')
current = vim.api.nvim_get_current_tabpage()
choose(selected)
assert(vim.api.nvim_get_current_tabpage() == current, 'stale selection changed tab')
vim.ui.select = original_select
render(true)
vim.cmd('tabclose')
render(true)
vim.cmd('tabonly')
render(true)
print('Passed ' .. checks .. ' tabline render checks and picker regressions')
vim.cmd('qa!')
