return {
  "WilliamHsieh/overlook.nvim",
  opts = {},
  keys = {
    { "<C-p>",  function() require("overlook.api").peek_definition() end, desc = "Overlook: Peek definition" },
    { "<C-px>", function() require("overlook.api").close_all() end,       desc = "Overlook: Close all popup" },
    { "<C-pu>", function() require("overlook.api").restore_popup() end,   desc = "Overlook: Restore popup" },
  },
}
