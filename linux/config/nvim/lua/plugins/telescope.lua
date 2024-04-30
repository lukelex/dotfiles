local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
  return
end

local actions = require("telescope.actions")
local builtin = require("telescope.builtin")

local finders = require("plugins.telescope.finders")

vim.keymap.set("n", "<Leader>p", finders.project_files, { noremap = true, silent = true })
vim.keymap.set("n", "<Leader>f", finders.find_files, {})
vim.keymap.set("n", "<Leader>b", builtin.buffers, {})
vim.keymap.set("n", "<Leader>g", finders.live_grep, {})
vim.keymap.set("n", "<Leader>s", finders.grep_string, {})
vim.keymap.set("n", "<Leader>r", builtin.lsp_references, {})
vim.keymap.set("n", "<Leader>d", builtin.diagnostics, {})
vim.keymap.set("n", "<Leader>q", builtin.quickfix, {})
vim.keymap.set("n", "<Leader>c", builtin.resume, { })

telescope.setup({
  defaults = {
    theme = "dropdown",
    layout_strategy = "vertical",
    layout_config = {
      vertical = {
        prompt_position = "top",
        height = 100
      }
    },
    mappings = {
      i = {
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,
        ["<Down>"] = actions.move_selection_next,

        ["<C-u>"] = actions.preview_scrolling_up,
        ["<C-d>"] = actions.preview_scrolling_down,
        ["<PageUp>"] = actions.preview_scrolling_up,
        ["<PageDown>"] = actions.preview_scrolling_down,

        ["<CR>"] = actions.select_tab_drop,
        ["<C-h>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["<C-t>"] = actions.select_tab,
        ["<C-q>"] = actions.send_to_qflist,
      }
    }
  }
})

require("telescope").load_extension("fzf")
