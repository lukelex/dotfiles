return {
  "mfussenegger/nvim-lint",
  event = { "BufRead" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      ["yaml.ghaction"] = { "actionlint" }
    }

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function(args)
        if vim.bo[args.buf].filetype == "yaml.ghaction" then
          lint.try_lint("actionlint")
        end
      end,
    })
  end
}
