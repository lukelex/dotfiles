return {
  "ibhagwan/fzf-lua",
  priority = 999,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
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
      function() FzfLua.quickfix() end,
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
          ["default"] = function(selected, opts)
            if #selected > 1 then
              fzf.actions.file_sel_to_qf(selected, opts)
            else
              smart_open.files(selected, opts)
            end
          end,
          ["ctrl-s"] = fzf.actions.file_split,
          ["ctrl-v"] = fzf.actions.file_vsplit,
          ["ctrl-t"] = fzf.actions.file_tabedit,
          ["ctrl-q"] = { fn = fzf.actions.file_sel_to_qf, prefix = "select-all" },
          ["alt-Q"] = fzf.actions.file_sel_to_ll,
        },
      },
      winopts = {
        -- fzf-lua enables Tree-sitter highlighting by default. Its first
        -- parser initialization can fail while searching Rails/Ruby files;
        -- this highlighting is optional and normal buffer highlighting stays
        -- enabled by nvim-treesitter.
        treesitter = false,
        preview = {
          layout = "vertical"
        },
      },
      -- The previewer has a separate Tree-sitter path from the fzf window.
      -- Disable it too; otherwise the first Ruby preview can still trigger
      -- the parser error even when main-window highlighting is off.
      previewers = {
        builtin = {
          treesitter = { enabled = false },
        },
      },
    })
  end,
}
