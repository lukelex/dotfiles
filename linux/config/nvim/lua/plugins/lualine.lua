local mode_map = {
  n = "(ᴗ_ ᴗ。)",
  nt = "(ᴗ_ ᴗ。)",
  i = "(•̀ - •́ )",
  R = "( •̯́ ₃ •̯̀)",
  v = "(⊙ _ ⊙ )",
  V = "(⊙ _ ⊙ )",
  no ="(ﾉ°□°ﾉ )",
  ["\22"] = "(⊙ _ ⊙ )",
  t = "(⌐■_■)",
  ['!'] = "(ﾉ°□°ﾉ )",
  c = "(ﾉ°□°ﾉ )",
  s = "SUB"
}
 -- (╯°□°）╯︵ ( ͜。͡ʖ͜。)

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
    lualine_a = {
      {
        "mode",
        icons_enabled = true,
        separator = {
          left = "",
          right = ""
        },
        fmt = function()
          return mode_map[vim.api.nvim_get_mode().mode] or vim.api.nvim_get_mode().mode
        end
      },
    },
    lualine_b = { "branch", "diff" },
    lualine_c = { },
    lualine_x = { "encoding", "fileformat" },
    lualine_y = { "progress" },
    lualine_z = { "location" }
  },
})
