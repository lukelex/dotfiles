return {
  {
    "mbbill/undotree",
    event = { "BufRead" },
    config = function()
      vim.keymap.set("n", "U", ":UndotreeToggle<CR>")
    end
  }
}
