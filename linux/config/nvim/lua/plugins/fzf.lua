return {
  "ibhagwan/fzf-lua",
  version = "*",
  priority = 999,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    -- {
    --   "<leader>g",
    --   function()
    --     local fzf = require("fzf-lua")
    --     local smart_open = require("utils.smart_open")
    --     fzf.files({
    --       actions = {
    --         ["default"] = function(selected)
    --           if not selected or not selected[1] then return end
    --           smart_open.open(selected[1])
    --         end
    --       }
    --     })
    --   end,
    --   desc = "Smart files",
    -- },
    {
      "<leader>f",
      function() FzfLua.files() end,
      desc = "Open file in workspace",
      noremap = true,
      silent = true,
    },
    {
      "<leader>gs",
      function() FzfLua.live_grep() end,
      desc = "Live Grep",
      noremap = true,
    },
    {
      "<leader>gw",
      function() FzfLua.grep_cword() end,
      desc = "Grep Word",
      noremap = true,
    },
    {
      "<leader>b",
      function() FzfLua.buffers() end,
      desc = "Open buffers",
      noremap = true,
      silent = true,
    },
    {
      "<leader>q",
      function() FzfLua.qflist() end,
      desc = "Quickfix List",
      noremap = true,
    },
    {
      "<leader>D",
      function() FzfLua.lsp_workspace_diagnostics() end,
      desc = "Workspace diagnostics",
    },
    {
      "<leader>r",
      function() FzfLua.resume() end,
      desc = "Resume Last Picker",
      noremap = true,
    },
    {
      "<leader>s",
      function() FzfLua.spell_suggest() end,
      desc = "Spell Suggestions",
      noremap = true,
    }
  },
  config = function()
    local fzf = require("fzf-lua")
    local smart_open = require("utils.smart_open")

    fzf.setup({
      actions = {
        files = {
          ["default"] = smart_open.files,
          ["ctrl-s"] = fzf.actions.file_split,
          ["ctrl-v"] = fzf.actions.file_vsplit,
          ["ctrl-t"] = fzf.actions.file_tabedit,
        },
      },
    })
  end,
}
