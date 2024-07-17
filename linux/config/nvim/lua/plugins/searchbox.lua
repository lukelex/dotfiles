local searchbox = require("searchbox")

searchbox.setup({
  defaults = {
    show_matches = true,
    clear_matches = false,
  },
  popup = {
    position = {
      row = "95%",
      col = "98%",
    }
  },
})

local local_search = function (options)
  return function()
    searchbox.match_all(options)
  end
end

vim.keymap.set("n", "/", local_search())
vim.keymap.set("n", "?", local_search({ reverse = true }))
vim.keymap.set("x", "/", local_search({ visual_mode = true }))
vim.keymap.set("x", "?", local_search({ visual_mode = true, reverse = true }))
vim.keymap.set("n", "<leader>h", ":SearchBoxClear<CR>")
