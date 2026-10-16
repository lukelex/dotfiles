return {
  { "echasnovski/mini.pairs",      opts = {}, event = { "InsertEnter" } },
  { "echasnovski/mini.cursorword", opts = { delay = 250 }, event = { "BufRead" } },
  {
    "echasnovski/mini.indentscope",
    opts = function()
      return { draw = { animation = require("mini.indentscope").gen_animation.none() } }
    end,
    event = { "BufRead" }
  },
  {
    "echasnovski/mini.diff",
    version = "*",
    event = { "BufRead" },
    opts = {}
  }
}
