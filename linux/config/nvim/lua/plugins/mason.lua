local servers = {
  "bashls",
  "solargraph",
  "standardrb", -- gem install erb
  "ts_ls",
  -- "denols",
  "eslint",
  "svelte",
  "html",
  "cssls",
  "marksman",
  "lua_ls",
  "sqlls",
  "dockerls",
  "docker_compose_language_service",
  "rust_analyzer",
  "slint_lsp",
  "tailwindcss",
  "vimls",
  "gopls",
  "hyprls",
  "yamlls"
}

return {
  "mason-org/mason-lspconfig.nvim",
  dependencies = {
    "saghen/blink.cmp",
    "neovim/nvim-lspconfig",
    { "mason-org/mason.nvim", opts = {} },
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      automatic_enable = false,
      ensure_installed = servers
    })

    local blink = require("blink.cmp")
    local capabilities = blink.get_lsp_capabilities()

    vim.lsp.config('*', {
      debounce_text_changes = 150,
      capabilities = capabilities
    })

    vim.lsp.config("solargraph", {
      root_markers = { "backend", "Gemfile", ".git" },
      init_options = { formatting = false },
      settings = {
        solargraph = {
          diagnostics = false,
          completion = true,
          formatting = false
        }
      },
    })

    vim.lsp.config("yamlls", {
      settings = {
        yaml = {
          customTags = {
            "!Equals sequence",
            "!FindInMap sequence", "!GetAtt scalar", "!GetAZs scalar", "!ImportValue scalar", "!Join sequence scalar",
            "!Ref scalar", "!Select sequence", "!Split sequence", "!Sub scalar", "!And sequence", "!Not sequence",
            "!Equals sequence", "!Sub sequence", "!ImportValue scalar", "!If sequence"
          }
        }
      }
    })

    local filetypes = {
      ruby =             { "solargraph", "standardrb" },
      javascript =       { "ts_ls", "eslint", "tailwindcss" },
      typescript =       { "ts_ls", "eslint", "tailwindcss" },
      svelte =           { "svelte", "tailwindcss" },
      html =             { "html", "tailwindcss" },
      css =              { "cssls", "tailwindcss" },
      markdown =         { "marksman" },
      lua =              { "lua_ls" },
      sql =              { "sqlls" },
      dockerfile =       { "dockerls" },
      docker_compose =   { "docker_compose_language_service" },
      rust =             { "rust_analyzer" },
      slint =            { "slint_lsp" },
      vim =              { "vimls" },
      go =               { "gopls" },
      hyprlang =         { "hyprls" },
      yaml =             { "yamlls" },
      ["yaml.docker-compose"] = { "docker_compose_language_service", "yamlls" },
      bash =             { "bashls" },
      sh =               { "bashls" },
    }

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local ft_servers = filetypes[args.match]
        if ft_servers then
          vim.lsp.enable(ft_servers)
        end
      end,
    })
  end
}
