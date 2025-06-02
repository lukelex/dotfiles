return {
  "folke/snacks.nvim",
  version = "*",
  priority = 1000,
  opts = {
    notifier = {
      enabled = true,
      timeout = 5000, -- default timeout in ms
    },
    quickfile = { enabled = true }
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local buf = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        vim.notify(
          string.format("'%s' attached to buffer", client.name),
          "info",
          { title = string.format("LSP Attach (%d)", buf) }
        )
      end,
    })
  end
}
