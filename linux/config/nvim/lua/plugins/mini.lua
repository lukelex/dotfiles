return {
  { "echasnovski/mini.pairs",      opts = {} },
  { "echasnovski/mini.cursorword", opts = { delay = 50 } },
  {
    "echasnovski/mini.indentscope",
    opts = {},
    event = { "BufRead" }
  },
  {
    "echasnovski/mini.diff",
    version = "*",
    event = { "BufRead" },
    opts = {}
  }
}
