-- Run: nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-roots.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local lspconfig = vim.env.LSPCONFIG_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nvim-lspconfig"
vim.opt.rtp:prepend(lspconfig)
local base = vim.fn.tempname()
local bufnr = vim.api.nvim_create_buf(false, true)

local function write(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ content or "" }, path)
end

local function root(path)
  vim.api.nvim_buf_set_name(bufnr, path)
  local found
  require("core.lsp-roots").tailwind(bufnr, function(dir) found = dir end)
  return found
end

local ok, err = xpcall(function()
  write(base .. "/.git")
  local cases = {
    { "v3", "tailwind.config.cjs" },
    { "v4", "package.json", '{"devDependencies":{"tailwindcss":"^4.0.0"}}' },
    { "json5", "package.json5", "{devDependencies: {tailwindcss: '^4.0.0'}}" },
    { "postcss", "postcss.config.mjs" },
    { "django", "theme/static_src/tailwind.config.ts" },
    { "ruby", "Gemfile.lock", "    tailwindcss-rails (4.0.0)" },
    { "elixir", "mix.lock", '"tailwind": {:hex, :tailwind, "0.2.0"}' },
  }
  for _, case in ipairs(cases) do
    local dir = base .. "/" .. case[1]
    write(dir .. "/" .. case[2], case[3])
    assert(root(dir .. "/src/app.ts") == dir, "root detection failed: " .. case[1])
  end
  write(base .. "/unrelated/package.json", '{"devDependencies":{"typescript":"latest"}}')
  assert(root(base .. "/unrelated/app.ts") == nil, "Git-only package started Tailwind")
  write(base .. "/broken/package.json", "{ malformed")
  assert(root(base .. "/broken/app.ts") == nil, "malformed manifest started Tailwind")
  write(base .. "/v4/packages/plain/package.json", '{}')
  assert(root(base .. "/v4/packages/plain/app.ts") == base .. "/v4", "wrong manifest selected")
  write(base .. "/v4/packages/nested/tailwind.config.ts")
  assert(root(base .. "/v4/packages/nested/app.ts") == base .. "/v4/packages/nested", "nearest root lost")
  write(base .. "/v4/separate/.git")
  assert(root(base .. "/v4/separate/app.ts") == nil, "search escaped nested Git repository")

  -- Exercise the actual plugin configuration without starting/installing servers.
  package.loaded.mason = { setup = function() end }
  package.loaded["mason-lspconfig"] = { setup = function() end }
  package.loaded["blink.cmp"] = { get_lsp_capabilities = function() return {} end }
  vim.lsp.enable = function() end
  dofile(config .. "/lua/plugins/mason.lua").config()
  local solargraph = vim.lsp.config.solargraph
  assert(solargraph and solargraph.root_markers, "installed nvim-lspconfig is required")
  write(base .. "/backend/Gemfile", 'source "https://rubygems.org"')
  assert(vim.fs.root(base .. "/backend/app/model.rb", solargraph.root_markers) == base .. "/backend",
    "Solargraph escaped the Gemfile root")
  assert(vim.lsp.config.tailwindcss.root_dir == require("core.lsp-roots").tailwind,
    "Tailwind root override was not applied")
  assert(vim.lsp.config.tailwindcss.workspace_required, "Tailwind must require a workspace")
end, debug.traceback)

vim.api.nvim_buf_delete(bufnr, { force = true })
vim.fn.delete(base, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end
print("PASS: Tailwind v3/v4 and nested roots, unrelated projects, Solargraph Gemfile root")
