require("lualine").setup({
  options = {
    theme = "railscasts",
    icons_enabled = true,
    globalstatus = true,
  },
  winbar = {
    lualine_a = { "filename" },
    lualine_z = { "diagnostics", "filetype" },
  },
  inactive_winbar = {
    lualine_a = { "filename" },
    lualine_z = { "diagnostics", "filetype" },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff" },
    lualine_c = { },
    lualine_x = { "encoding", "fileformat" },
    lualine_y = { "progress" },
    lualine_z = { "location" }
  },
})

