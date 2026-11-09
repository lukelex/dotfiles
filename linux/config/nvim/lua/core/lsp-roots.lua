local M = {}

local tailwind_markers = {
  "tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts",
  "postcss.config.js", "postcss.config.cjs", "postcss.config.mjs", "postcss.config.ts",
  "theme/static_src/tailwind.config.js", "theme/static_src/tailwind.config.cjs",
  "theme/static_src/tailwind.config.mjs", "theme/static_src/tailwind.config.ts",
  "theme/static_src/postcss.config.js",
}

local function read(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

local function contains(path, needle)
  local text = read(path)
  return text ~= nil and text:find(needle, 1, true) ~= nil
end

local function package_has_tailwind(path)
  local text = read(path)
  if not text then return false end
  local ok, manifest = pcall(vim.json.decode, text)
  if not ok or type(manifest) ~= "table" then return false end
  for _, field in ipairs({ "dependencies", "devDependencies", "peerDependencies", "optionalDependencies" }) do
    if type(manifest[field]) == "table" then
      for name, version in pairs(manifest[field]) do
        if type(name) == "string" and type(version) == "string"
          and (name == "tailwindcss" or vim.startswith(name, "@tailwindcss/")) then
          return true
        end
      end
    end
  end
  return false
end

function M.tailwind(bufnr, on_dir)
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  while dir do
    for _, marker in ipairs(tailwind_markers) do
      if vim.uv.fs_stat(dir .. "/" .. marker) then
        on_dir(dir)
        return
      end
    end
    -- Match each manifest at its own directory, rather than treating every
    -- package.json as a root after finding Tailwind in an unrelated ancestor.
    -- Package detection preserves CSS-first v4 projects without a JS config.
    if package_has_tailwind(dir .. "/package.json")
      -- Retain upstream's text fallback for JSON5/Ruby/Elixir manifests; they
      -- cannot be parsed with Neovim's JSON decoder.
      or contains(dir .. "/package.json5", "tailwindcss")
      or contains(dir .. "/Gemfile.lock", "tailwind")
      or contains(dir .. "/mix.lock", "tailwind") then
      on_dir(dir)
      return
    end
    -- Git marks the search boundary, not evidence of a Tailwind project.
    if vim.uv.fs_stat(dir .. "/.git") then
      return
    end
    dir = vim.fs.dirname(dir)
  end
end

return M
