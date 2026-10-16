local function lsp_count()
  local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

  return #clients
end

local function win_width(minimum)
  return function() return vim.api.nvim_win_get_width(0) >= minimum end
end

local function screen_width(minimum)
  return function() return vim.o.columns >= minimum end
end

local components = {
  filename = {
    "filename",
    path = 1,
    globalstatus = false, -- Shorten against this split, not the global statusline.
    shorting_target = 30,
    separator = {
      left = "",
      right = ""
    }
  },
  diff = {
    "diff",
    cond = win_width(60),
    source = function()
      local summary = vim.b.minidiff_summary
      if not summary then return nil end
      return { added = summary.add, modified = summary.change, removed = summary.delete }
    end,
    symbols = { added = " ", modified = " ", removed = " " },
    diff_color = {
      added = { fg = "#87AF5F" },
      modified = { fg = "#6D9CBE" },
      removed = { fg = "#DA4939" },
    },
    separator = {
      right = ""
    }
  },
  lsp = {
    lsp_count,
    cond = function() return vim.api.nvim_win_get_width(0) >= 110 and lsp_count() > 0 end,
    icon = " ",
    separator = {
      left = "",
    }
  },
  diagnostics = {
    "diagnostics",
    cond = win_width(45),
    separator = {
      left = "",
    }
  },
  filetype = {
    "filetype",
    cond = win_width(70),
    separator = {
      left = "",
      right = ""
    }
  },
  mode = {
    "mode",
    separator = {
      left = "",
      right = ""
    },
  },
  branch = {
    "branch",
    cond = screen_width(60),
    icon = "",
    fmt = function(str)
      if vim.api.nvim_strwidth(str) > 25 then
        local shortened = str
        while vim.fn.strdisplaywidth(shortened) > 24 do
          shortened = vim.fn.strcharpart(shortened, 0, vim.fn.strchars(shortened) - 1)
        end
        return shortened .. "…"
      end

      return str
    end,
    separator = {
      right = ""
    }
  },
  progress = {
    "progress",
    cond = screen_width(80),
    icon = " ",
    separator = {
      left = "",
    }
  },
  location = {
    "location",
    icon = "",
    separator = {
      left = "",
      right = ""
    }
  }
}

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons"
    },
    opts = function()
      local colors = require("railscasts.colors")
      local theme = vim.deepcopy(require("lualine.themes.railscasts"))
      theme.inactive.a = { bg = colors.light_grey, fg = colors.black }
      theme.inactive.b = { bg = colors.grey, fg = colors.beige_grey }

      return {
      options = {
        theme = theme,
        icons_enabled = true,
        globalstatus = true,
        refresh = {
          winbar = 300,
          tabline = 1000,
          statusline = 1000,
        },
      },
      winbar = {
        lualine_a = { components.filename },
        lualine_b = { components.diff },
        lualine_y = { components.lsp, components.diagnostics },
        lualine_z = { components.filetype },
      },
      inactive_winbar = {
        lualine_a = { components.filename },
        lualine_b = { components.diff },
        lualine_y = { components.lsp, components.diagnostics },
        lualine_z = { components.filetype },
      },
      sections = {
        lualine_a = { components.mode },
        lualine_b = { components.branch },
        lualine_c = {
          { function()
            local register = vim.fn.reg_recording()
            return register ~= "" and ("REC @" .. register) or ""
          end, color = { fg = "#DA4939", gui = "bold" } },
        },
        lualine_x = {
          { "searchcount", cond = screen_width(60) },
          { "encoding", cond = function()
            local encoding = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
            return encoding:lower() ~= "utf-8"
          end },
          { "fileformat", cond = function() return vim.bo.fileformat ~= "unix" end },
        },
        lualine_y = { components.progress },
        lualine_z = { components.location }
      },
      }
    end,
  }
}
