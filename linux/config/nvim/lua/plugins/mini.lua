return {
  { "echasnovski/mini.pairs",      opts = {}, event = { "InsertEnter" } },
  { "echasnovski/mini.cursorword", opts = { delay = 50 }, event = { "BufRead" } },
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
