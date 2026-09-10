return {
  {
    "catgoose/nvim-colorizer.lua",
    event = { "BufRead" },
    config = function()
      vim.opt.termguicolors = true

      require("colorizer").setup()
    end
  }
}
