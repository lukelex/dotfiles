local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
  return
end

local actions = require("telescope.actions")
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<Leader>p", builtin.git_files, {})
vim.keymap.set("n", "<Leader>f", builtin.find_files, {})
vim.keymap.set("n", "<Leader>b", builtin.buffers, {})
vim.keymap.set("n", "<Leader>g", builtin.live_grep, {})
vim.keymap.set("n", "<Leader>s", builtin.grep_string, {})
vim.keymap.set("n", "<Leader>r", builtin.lsp_references, {})
vim.keymap.set("n", "<Leader>d", builtin.diagnostics, {})

telescope.setup({
  pickers = {
    find_files = { theme = "ivy", },
    git_files = { theme = "ivy" },
    buffers = { theme = "ivy", },
    live_grep = { theme = "ivy", },
    grep_string = { theme = "ivy", },
    lsp_references = { theme = "ivy", },
    diagnostics = { theme = "ivy", },
  },
  defaults = {
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

        ["<CR>"] = actions.select_default,
        ["<C-h>"] = actions.select_horizontal,
        ["<C-v>"] = actions.select_vertical,
        ["<C-t>"] = actions.select_tab,
      }
    }
  }
})
