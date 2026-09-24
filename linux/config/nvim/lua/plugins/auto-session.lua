return {
  'rmagatti/auto-session',
  lazy = false,

  -- A session can become unloadable when Neovim is interrupted while it is
  -- being written (or after a plugin changes one of the commands in it). The
  -- default handler only disables autosave, so the same file is tried again
  -- on every boot. Move it out of the way so the next launch can start cleanly.
  ---enables autocomplete for opts
  ---@module 'auto-session'
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/projects', '~/Downloads', '/' },
    restore_error_handler = function(error_msg)
      local session = vim.v.this_session
      local root = vim.fn.stdpath('data') .. '/sessions/'
      local log_file = vim.fn.stdpath('log') .. '/auto-session.log'

      local function log(message)
        vim.fn.mkdir(vim.fn.fnamemodify(log_file, ':h'), 'p')
        vim.fn.writefile({ os.date('%Y-%m-%d %H:%M:%S ') .. message }, log_file, 'a')
      end

      if session ~= '' and vim.startswith(session, root) and vim.fn.filereadable(session) == 1 then
        local quarantine = session .. '.broken-' .. os.time()
        if vim.fn.rename(session, quarantine) == 0 then
          log('Moved unloadable session to ' .. quarantine)
        end
      end

      log('Error restoring session; autosave disabled: ' .. error_msg)
      return false
    end,
    -- log_level = 'debug',
  }
}
