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
    if map.desc == desc then return map.callback() end
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
assert(compact_text:find('^%d+ '), 'compact label lost number prefix')
assert(compact_text:find('100%%'), 'compact label lost workspace name')
vim.o.columns = 80
vim.cmd('tabnext 1')
local before = render(true)
mapping('Page tabline right')
local after = render(false)
assert(after[1] == before[#before] + 1, 'forward page did not advance a viewport')
mapping('Page tabline left')
assert(render(false)[1] < after[1], 'backward page did not move left')
for _ = 1, 20 do mapping('Page tabline left') end
assert(render(false)[1] == 1, 'backward paging did not reach start')
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

-- Indicators count non-floating windows and only their displayed buffers.
-- Evaluate the renderer directly while resizing this headless instance; avoid
-- drawing native click regions until the UI has processed the resize.
vim.o.showtabline = 0
vim.o.columns = 120
vim.cmd('silent only')
names.set(0, 'Workspace')
vim.bo.modified = false
local _, clean = render(true)
assert(not clean:find('●', 1, true), 'clean tab marked modified')
local hidden = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, { 'hidden changes' })
assert(not select(2, render(true)):find('●', 1, true), 'hidden buffer marked workspace modified')
local displayed = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(displayed, 0, -1, false, { 'visible changes' })
local _, dirty = render(true)
assert(dirty:find('●', 1, true), 'displayed modification missing')
assert(vim.fn.strdisplaywidth(clean) == vim.fn.strdisplaywidth(dirty), 'modified marker shifted layout')
vim.bo.modified = false
vim.cmd('vsplit')
local _, split_text = render(true)
assert(split_text:find('Workspace', 1, true) and split_text:find(' ×2%s+$'), 'window count is not before the close slot')
local floating = vim.api.nvim_open_win(hidden, false, {
  relative = 'editor', row = 2, col = 2, width = 10, height = 2, style = 'minimal',
})
local _, floating_text = render(true)
assert(floating_text:find('×2', 1, true) and not floating_text:find('×3', 1, true), 'float counted as workspace window')
assert(not floating_text:find('●', 1, true), 'floating buffer marked workspace modified')
vim.api.nvim_win_close(floating, true)
names.set(0, '')
local _, fallback = render(true)
assert(fallback:find('×2', 1, true) and not fallback:find('[1+]', 1, true), 'fallback duplicated window count')
names.set(0, 'Workspace')
vim.cmd('tabnew')
names.set(0, 'Other')
local _, buttons = render(true)
assert(buttons:find('×2 ', 1, true), 'inactive count did not occupy the close slot')
local left_gap, right_gap = buttons:match('1( +)Workspace( +)×2')
assert(left_gap and math.abs(#left_gap - #right_gap) <= 1, 'inactive filename padding is not balanced')
local _, close_count = buttons:gsub('', '')
assert(close_count == 1, 'inactive tab has a close button')
local before_focus = vim.fn.strdisplaywidth(buttons)
vim.cmd('tabnext 1')
local _, focused = render(true)
assert(focused:find('×2 ', 1, true), 'active count did not leave room for the close button')
left_gap, right_gap = focused:match('1( +)Workspace( +)×2')
assert(left_gap and math.abs(#left_gap - #right_gap) <= 1, 'active filename padding is not balanced')
assert(vim.fn.strdisplaywidth(focused) == before_focus, 'focus change shifted labels')
names.set(0, '/very/long/project/root/server/handlers/user.lua')
local _, path_label = render(true)
assert(path_label:find('…', 1, true) and path_label:find('handlers/user.lua', 1, true), 'path truncation lost meaningful suffix')
names.set(0, 'A-very-long-descriptive-workspace-END')
local _, middle_label = render(true)
assert(middle_label:find('A-very', 1, true) and middle_label:find('END', 1, true), 'name truncation lost either end')
local active_hl = vim.api.nvim_get_hl(0, { name = 'DotfilesTabActive', link = false })
assert(active_hl.bold and not active_hl.underline, 'active tab styling is incorrect')
vim.api.nvim_set_hl(0, 'TabLineSel', { fg = '#abcdef', bg = '#123456' })
vim.api.nvim_exec_autocmds('ColorScheme', {})
active_hl = vim.api.nvim_get_hl(0, { name = 'DotfilesTabActive', link = false })
assert(active_hl.fg == 0xabcdef and active_hl.bold and not active_hl.underline, 'highlights did not follow colorscheme')

-- Exercise wheel routing without an attached mouse; outside the bar it must
-- return the native key, while bar scrolling never changes the selected tab.
for i = 3, 12 do
  vim.cmd('tabnew')
  names.set(0, 'workspace' .. i)
end
vim.cmd('tabnext 1')
vim.o.columns = 80
vim.o.showtabline = 2
render(true)
local original_mouse = vim.fn.getmousepos
local mouse_row = 1
vim.fn.getmousepos = function() return { screenrow = mouse_row } end
local wheel_current = vim.api.nvim_get_current_tabpage()
assert(mapping('Scroll tabline with ScrollWheelDown') == '<Ignore>', 'bar wheel not consumed')
assert(vim.wait(1000, function() return render(false)[1] == 2 end), 'wheel did not scroll right')
local _, position_text = render(false)
assert(position_text:find('tabs 2–', 1, true) and position_text:find('←active 1', 1, true), 'browsing position/active direction missing')
assert(vim.api.nvim_get_current_tabpage() == wheel_current, 'wheel changed workspace')
assert(mapping('Scroll tabline with ScrollWheelUp') == '<Ignore>')
assert(vim.wait(1000, function() return render(false)[1] == 1 end), 'wheel did not scroll left')
assert(mapping('Scroll tabline with ScrollWheelRight') == '<Ignore>')
assert(vim.wait(1000, function() return render(false)[1] == 2 end), 'horizontal wheel did not scroll right')
assert(mapping('Scroll tabline with ScrollWheelLeft') == '<Ignore>')
assert(vim.wait(1000, function() return render(false)[1] == 1 end), 'horizontal wheel did not scroll left')
mouse_row = 4
assert(mapping('Scroll tabline with ScrollWheelDown') == '<ScrollWheelDown>', 'buffer wheel was intercepted')
mouse_row = 1
vim.o.showtabline = 0
assert(mapping('Scroll tabline with ScrollWheelDown') == '<ScrollWheelDown>', 'hidden bar intercepted wheel')
vim.o.showtabline = 2
vim.fn.getmousepos = original_mouse
vim.cmd('tabnext 12')
render(true)
for _ = 1, 20 do mapping('Scroll tabline left') end
assert(select(2, render(false)):find('→active 12', 1, true), 'rightward active indicator missing')
for _, width in ipairs({ 12, 20, 40, 69, 70, 80, 160 }) do
  vim.o.showtabline = 0
  vim.o.columns = width
  render(false)
  mapping('Scroll tabline right')
  render(false)
end
print('Passed ' .. checks .. ' tabline render checks and picker regressions')
vim.cmd('qa!')
