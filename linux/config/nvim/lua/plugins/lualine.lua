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

local components = {
  filename = {
    "filename",
    path = 1,
    fmt = pathd,
    separator = {
      left = "",
      right = ""
    }
  },
  diff = {
    "diff",
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
    icon = " ",
    separator = {
      left = "",
    }
  },
  diagnostics = {
    "diagnostics",
    separator = {
      left = "",
    }
  },
  filetype = {
    "filetype",
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
    icon = "",
    fmt = function(str)
      if vim.api.nvim_strwidth(str) > 25 then
        return ("%s…"):format(str:sub(1, 24))
      end

      return str
    end,
    separator = {
      right = ""
    }
  },
  progress = {
    "progress",
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
    opts = {
      options = {
        theme = "railscasts",
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
        lualine_c = {},
        lualine_x = { "encoding", "fileformat" },
        lualine_y = { components.progress },
        lualine_z = { components.location }
      },
    }
  }
}
