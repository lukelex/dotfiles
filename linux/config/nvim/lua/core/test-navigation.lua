local M = {}

local function normalize_path(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function paths_equal(left, right)
  return normalize_path(left) == normalize_path(right)
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

local function find_buffer_with_file(target_path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local bufname = vim.api.nvim_buf_get_name(buf)

      if bufname ~= "" and paths_equal(bufname, target_path) then
        return buf
      end
    end
  end

  return nil
end

local function find_window_with_buffer(target_buf)
  local current_win = vim.api.nvim_get_current_win()

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= current_win
        and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win) == target_buf then
      return win
    end
  end

  return nil
end

local function open_buffer_in_vsplit(buf)
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

local function open_file_in_vsplit(path)
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

local function target_path_for(filepath)
  if filepath:match("/backend/app/") then
    return path_to_test(filepath)
  end

  if filepath:match("/backend/spec/") then
    return path_to_source(filepath)
  end

  return nil
end

function ToggleTestFile()
  local filepath = vim.fn.expand("%:p")
  local target_path = target_path_for(filepath)

  if not target_path then
    print("Not in app/ or spec/ file.")
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_win_get_buf(current_win)
  local target_buf = find_buffer_with_file(target_path)

  -- 1. Target is already visible in the current window.
  if target_buf and current_buf == target_buf then
    vim.api.nvim_set_current_win(current_win)
    return
  end

  -- 2. Target is visible in another window.
  if target_buf then
    local target_win = find_window_with_buffer(target_buf)

    if target_win then
      vim.api.nvim_set_current_win(target_win)
      return
    end

    -- 3. Target buffer exists but is not visible.
    open_buffer_in_vsplit(target_buf)
    return
  end

  -- 4. Target file exists on disk.
  -- 5. Target file does not exist: this still opens a named, unsaved buffer.
  open_file_in_vsplit(target_path)
end

function M.setup()
  vim.keymap.set("n", "<Space>t", function()
    ToggleTestFile()
  end, { desc = "Open test file in vertical split" })
end

return M
