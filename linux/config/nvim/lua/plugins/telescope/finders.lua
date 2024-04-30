local builtin = require("telescope.builtin")

local M = { }

M.find_files = function(options)
  local all_options = {
    hidden = true,
  }
  for k,v in pairs(options or {}) do all_options[k] = v end

  builtin.find_files(all_options)
end

M.project_files = function()
  vim.fn.system("git rev-parse --is-inside-work-tree")
  local is_inside_work_tree = vim.v.shell_error == 0

  if is_inside_work_tree then
    builtin.git_files()
  else
    M.find_files({ no_ignore = true })
  end
end

local ripgrep_args = {
  glob_pattern = {
    '!.git/',
    '!tmp/',
    -- '!*.log',
  },
  additional_args = {
    "--no-ignore",
    "--hidden"
  }
}

M.live_grep = function()
  builtin.live_grep(ripgrep_args)
end

M.grep_string = function()
  builtin.grep_string(ripgrep_args)
end

return M
