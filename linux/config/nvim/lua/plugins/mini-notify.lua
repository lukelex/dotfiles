return {
  "folke/snacks.nvim",
  version = "*",
  priority = 1000,
  opts = {
    notifier = { enabled = true },
    quickfile = { enabled = true }
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local buf = args.buf

        vim.notify(
          string.format("LSP '%s' attached to buffer %d", client.name, buf),
          "info",
          { title = "LSP Attach" }
        )
      end,
    })
  end
}
