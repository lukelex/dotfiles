return {
  "mfussenegger/nvim-lint",
  event = { "BufRead" },
  config = function()
    require('lint').linters_by_ft = {
      ["yaml.ghaction"] = { "actionlint" }
    }
  end
}
