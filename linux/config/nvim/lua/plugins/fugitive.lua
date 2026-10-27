return {
  "tpope/vim-fugitive",
  event = { "BufRead" },
  keys = {
    {
      "gb",
      function()
        local source_win = vim.api.nvim_get_current_win()
        vim.cmd.Git({ "blame" })
        local blame_win = vim.api.nvim_get_current_win()
        vim.b[vim.api.nvim_win_get_buf(blame_win)].dotfiles_blame_source_win = source_win
      end,
      desc = "Git blame",
      mode = "n",
    },
  },
  config = function()
    local group = vim.api.nvim_create_augroup("FugitiveBlame", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "fugitiveblame",
      callback = function(args)
        vim.wo[0].cursorline = true
        vim.wo[0].winhighlight = "CursorLine:Visual"
        local blame_win = vim.api.nvim_get_current_win()
        vim.api.nvim_create_autocmd("CursorMoved", {
          group = group,
          callback = function()
            if not vim.api.nvim_win_is_valid(blame_win) then
              return
            end
            local blame_buf = vim.api.nvim_win_get_buf(blame_win)
            local source_win = vim.b[blame_buf].dotfiles_blame_source_win
            if not source_win or not vim.api.nvim_win_is_valid(source_win) then
              return
            end
            if vim.api.nvim_get_current_win() ~= source_win then
              return
            end
            local source_cursor = vim.api.nvim_win_get_cursor(source_win)
            local blame_line_count = vim.api.nvim_buf_line_count(blame_buf)
            vim.api.nvim_win_set_cursor(blame_win, {
              math.min(source_cursor[1], blame_line_count),
              0,
            })
          end,
        })
        vim.keymap.set("n", "q", "<Cmd>close<CR>", {
          buffer = args.buf,
          silent = true,
          desc = "Close blame viewer",
        })
      end,
    })
  end,
}
