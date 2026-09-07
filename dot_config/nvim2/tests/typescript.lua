-- nvim --headless -u NONE -i NONE -l ~/.config/nvim2/tests/typescript.lua
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
local typescript = require("config.typescript.project")
local formatting = require("config.formatting.typescript")
local tmp = vim.fn.tempname()
local count = 0
local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(contents, "\n", { plain = true }), path)
end
local function eq(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
  count = count + 1
end
local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
  count = count + 1
end
local ok, err = xpcall(function()
  local root = tmp .. "/repo"
  local file = root .. "/packages/app/src/main.tsx"
  vim.fn.mkdir(root .. "/.git", "p")
  write(root .. "/package.json", '{"devDependencies":{"prettier":"*","tailwindcss":"*"}}')
  write(root .. "/packages/app/package.json", "{}")
  write(file, 'export const App = () => <div className="text-red-500" />')
  local context = typescript.new(file)
  eq(context.root, root)
  eq(context.dependency("tailwindcss"), true)
  eq(formatting.select(file, false), nil) -- installed/declared tools aren't policy
  eq(formatting.select(file, true).formatter, "prettier")
  write(root .. "/.prettierrc", "{}")
  eq(formatting.select(file, false).formatter, "prettier")
  write(root .. "/biome.jsonc", '{ // delegated to Biome\n "formatter": {"enabled":false},\n}')
  fails(function()
    formatting.select(file, false)
  end, "Both Prettier and Biome")
  write(root .. "/.nvim.json", '{"typescript":{"formatter":"prettier"}}')
  eq(formatting.select(file, false).formatter, "prettier")
  write(root .. "/packages/app/.nvim.json", '{"typescript":{"formatter":false}}')
  eq(formatting.select(file, false).disabled, true)
  eq(formatting.select(file, true).disabled, true)
  write(root .. "/packages/app/.nvim.json", '{"typescript":{"formatter":"eslint"}}')
  fails(function()
    formatting.select(file, true)
  end, "typescript.formatter must be")
  write(root .. "/packages/app/.nvim.json", '{"typescript":{"formatter":"biome"}}')
  eq(formatting.select(file, false).formatter, "biome")
  local binary = root .. "/node_modules/.bin/prettier"
  write(binary, "#!/bin/sh\nexit 0")
  vim.fn.setfperm(binary, "rwx------")
  eq(typescript.new(file).command("prettier"), binary)
  local nested = root .. "/vendor/lib/src/main.ts"
  vim.fn.mkdir(root .. "/vendor/lib/.git", "p")
  write(nested, "const x=1")
  eq(formatting.select(nested, false), nil)
  eq(typescript.new(nested).dependency("tailwindcss"), false)
  eq(typescript.new(nested).command("prettier"), "prettier")
  local plain = tmp .. "/plain/main.js"
  write(plain, "const x=1")
  eq(formatting.select(plain, false), nil)
  write(tmp .. "/plain/package.json", '{"prettier":{"semi":false}}')
  eq(formatting.select(plain, false).formatter, "prettier")
  require("config.typescript").setup()
  local function enabled(server, path)
    local buf = vim.fn.bufadd(path)
    local called = false
    vim.lsp.config[server].root_dir(buf, function()
      called = true
    end)
    return called
  end
  eq(enabled("tailwindcss", file), true) -- v4 without a tailwind.config file
  eq(enabled("tailwindcss", plain), false)
  eq(enabled("biome", file), true)
  eq(enabled("biome", plain), false)
  eq(enabled("eslint", plain), false)
  write(tmp .. "/plain/eslint.config.mjs", "export default []")
  eq(enabled("eslint", plain), true)
  eq(enabled("vtsls", plain), true)
  write(tmp .. "/plain/deno.json", "{}")
  eq(enabled("vtsls", plain), false)
end, debug.traceback)
vim.fn.delete(tmp, "rf")
if not ok then
  error(err)
end
print("TypeScript project policy: " .. count .. " assertions passed")
