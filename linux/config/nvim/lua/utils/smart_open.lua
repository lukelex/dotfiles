local M = {}

-- Rules:
-- 1. When there's no buffer with the chosen file, open it in the current window and tab.
-- 2. When there's an existing buffer open in a window in the current tab, switch focus to it.
-- 3. When there's an existing buffer open in another window on a different tab, switch focus to it.
-- 4. When there's a buffer but it's not visible in any window on any tab, open in the current window.
-- 5. If the buffer is open in multiple windows on different tabs, including the current tab, prioritize the window on the current tab

function M.files(selected, opts)
  if not selected or #selected == 0 then return end

  local path_utils = require("fzf-lua.path")

  local entry = path_utils.entry_to_file(selected[1], opts)
  local target_path = vim.fn.fnamemodify(entry.path, ":p")

  local current_tab = vim.api.nvim_get_current_tabpage()
  local all_wins = vim.api.nvim_list_wins()
  local target_win = nil

  -- 1. Check current tab first (Rule 2 & 5)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p") == target_path then
      target_win = win
      break
    end
  end

  -- 2. If not found in current tab, check everywhere else (Rule 3)
  if not target_win then
    for _, win in ipairs(all_wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p") == target_path then
        target_win = win
        break
      end
    end
  end

  -- 3. Execution phase
  if target_win then
    -- We found a window (either in current tab or elsewhere)
    vim.api.nvim_set_current_win(target_win)
  else
    -- Rule 1 & 4: Not visible anywhere? Open in current window
    vim.cmd.edit(vim.fn.fnameescape(entry.path))
  end
end

return M
