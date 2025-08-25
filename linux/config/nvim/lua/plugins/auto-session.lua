return {
  'rmagatti/auto-session',
  lazy = false,

  ---enables autocomplete for opts
  ---@module 'auto-session'
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/projects', '~/Downloads', '/' },
    -- log_level = 'debug',
  }
}
