local builtin = require("telescope.builtin")
local theme = require('telescope.themes')

local M = {}

local function merge_tables(first, second)
  local all_options = {}

  for k, v in pairs(first or {}) do all_options[k] = v end
  for k, v in pairs(second or {}) do all_options[k] = v end

  return all_options
end

M.all_files = function(options)
  local all_options = { hidden = true, }

  builtin.find_files(merge_tables(all_options, options))
end

M.project_files = function()
  vim.fn.system("git rev-parse --is-inside-work-tree")
  local is_inside_work_tree = vim.v.shell_error == 0

  if is_inside_work_tree then
    builtin.git_files({
      show_untracked = true
    })
  else
    M.all_files({ no_ignore = true })
  end
end

local ripgrep_args = {
  glob_pattern = {
    '!.git/',
    '!tmp/',
    '!vendor/',
    '!log/',
    '!target/',
    '!_cacache/',
    '!.cache/',
    '!node_modules/',
    '!**/storage/',
    '!build/',
    '!.svelte-kit/',
    -- '!*.log',
  },
  additional_args = {
    "--no-ignore",
    "--hidden"
  }
}

M.string_global = function()
  builtin.live_grep(merge_tables(ripgrep_args, { glob_pattern = {} }))
end

M.word = function()
  builtin.grep_string(ripgrep_args)
end

M.string = function()
  builtin.live_grep(ripgrep_args)
end

M.spell_check = function()
  builtin.spell_suggest(
    theme.get_cursor {
      prompt_title = "",
      layout_config = {
        height = 0.25,
        width = 0.25
      }
    })
end

return M
