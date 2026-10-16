local M = {}

function M.open()
  local names = require('tabby.feature.tab_name')
  local current = vim.api.nvim_get_current_tabpage()
  local items = {}
  for number, tab in ipairs(vim.api.nvim_list_tabpages()) do
    items[#items + 1] = {
      tab = tab,
      number = number,
      name = names.get(tab):gsub('[%c]', ' '),
      current = tab == current,
    }
  end

  vim.ui.select(items, {
    prompt = 'Tabs',
    kind = 'tab',
    format_item = function(item)
      return string.format('%d/%s%s', item.number, item.name, item.current and ' (current)' or '')
    end,
    -- Override the file picker's window-selection mapping for this picker.
    snacks = {
      win = { input = { keys = { ['<CR>'] = { 'confirm', mode = { 'n', 'i' } } } } },
    },
  }, function(item)
    if not item or not vim.api.nvim_tabpage_is_valid(item.tab) then return end
    -- Use the handle: tab numbers can change while the picker is open.
    vim.api.nvim_set_current_tabpage(item.tab)
    vim.api.nvim_exec_autocmds('User', { pattern = 'DotfilesTabPicked' })
    vim.cmd('redrawtabline')
  end)
end

return M
