local function lsp_count()
  local clients = vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })

  return #clients
end

local function pathd(str)
  local parts = vim.split(str, "/", { plain = true })

  if #parts >= 2 then
    return parts[#parts - 1] .. "/" .. parts[#parts]
  else
    return str
  end
end

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons"
    },
    config = function()
      require("lualine").setup({
        options = {
          theme = "railscasts",
          icons_enabled = true,
          globalstatus = true,
          refresh = {
            winbar = 300,
            tabline = 1000,
            statusline = 1000,
            events = {
              "WinEnter",
              "BufEnter",
              "BufWritePost",
              "SessionLoadPost",
              "FileChangedShellPost",
              "VimResized",
              "Filetype",
              -- "CursorMoved",
              -- "CursorMovedI",
              "ModeChanged",
            },
          }
        },
        winbar = {
          lualine_a = { { "filename", path = 1, fmt = pathd } },
          lualine_b = {
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              diff_color = {
                added = { fg = "#87AF5F" },
                modified = { fg = "#6D9CBE" },
                removed = { fg = "#DA4939" },
              },
            }
          },
          lualine_y = { { lsp_count, icon = " " } },
          lualine_z = { "diagnostics", "filetype" },
        },
        inactive_winbar = {
          lualine_a = { { "filename", path = 1, fmt = pathd } },
          lualine_b = { {
            "diff",
            symbols = { added = " ", modified = " ", removed = " " },
            diff_color = {
              added = { fg = "#87AF5F" },
              modified = { fg = "#6D9CBE" },
              removed = { fg = "#DA4939" },
            },
          } },
          lualine_y = { { lsp_count, icon = " " } },
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
            },
          },
          lualine_b = {
            {
              "branch",
              icon = "",
              fmt = function(str)
                if vim.api.nvim_strwidth(str) > 25 then
                  return ("%s…"):format(str:sub(1, 24))
                end

                return str
              end,
            }
          },
          lualine_c = {},
          lualine_x = { "encoding", "fileformat" },
          lualine_y = { { "progress", icon = " " } },
          lualine_z = { { "location", icon = "" } }
        },
      })
    end
  }
}
