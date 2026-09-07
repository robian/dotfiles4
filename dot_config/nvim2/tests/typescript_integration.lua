-- Set NVIM_TYPESCRIPT_TEST_TOOLS to a directory with node_modules containing:
-- typescript, eslint, tailwindcss, @types/react, prettier and @biomejs/biome.
-- NVIM_APPNAME=nvim2 nvim --headless -i NONE -n \
--   '+luafile ~/.config/nvim2/tests/typescript_integration.lua' '+qa!'
local tmp = vim.fn.tempname()
local tools = assert(vim.env.NVIM_TYPESCRIPT_TEST_TOOLS, "Set NVIM_TYPESCRIPT_TEST_TOOLS")
local count = 0
local function check(value, message)
  assert(value, message)
  count = count + 1
end
local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(contents, "\n", { plain = true }), path)
end
local function fixture(name, files)
  local root = tmp .. "/" .. name
  vim.fn.mkdir(root .. "/.git", "p")
  assert(vim.uv.fs_symlink(tools .. "/node_modules", root .. "/node_modules", { dir = true }))
  write(root .. "/package.json", "{}")
  for path, contents in pairs(files) do
    write(root .. "/" .. path, contents)
  end
  return root
end
local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end
local function lines(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function client(name, buf)
  local found
  check(
    vim.wait(20000, function()
      found = vim.lsp.get_clients({ name = name, bufnr = buf })[1]
      return found and found.initialized
    end, 50),
    name .. " did not attach"
  )
  return found
end
local function diagnostic(buf, pattern)
  check(
    vim.wait(20000, function()
      for _, d in ipairs(vim.diagnostic.get(buf)) do
        if d.message:lower():find(pattern:lower(), 1, true) then
          return true
        end
      end
    end, 50),
    "Missing diagnostic: " .. pattern .. " " .. vim.inspect(vim.diagnostic.get(buf))
  )
end
local ok, err = xpcall(function()
  local root = fixture("tsx", {
    ["package.json"] = '{"dependencies":{"tailwindcss":"*","typescript":"*"}}',
    ["tsconfig.json"] = '{"compilerOptions":{"jsx":"react-jsx","strict":true,"module":"NodeNext"}}',
    ["src/styles.css"] = '@import "tailwindcss";',
    ["src/Other.jsx"] = "export const Other = () => <div />;",
    ["src/App.tsx"] = 'export const App = () => <div className="text-red-500" />;\nexport const bad: number = "wrong";\nexport function size(name: string) { return name.length; }',
  })
  local buf = open(root .. "/src/App.tsx")
  local ts = client("vtsls", buf)
  diagnostic(buf, "not assignable")
  check(vim.bo[buf].filetype == "typescriptreact", "TSX filetype")
  check(vim.treesitter.get_parser(buf):lang() == "tsx", "TSX parser")
  local hints = ts:request_sync("textDocument/inlayHint", {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 3, character = 0 } },
  }, 10000, buf)
  check(hints and hints.result and #hints.result > 0, "TypeScript inlay hints")
  local tailwind = client("tailwindcss", buf)
  local hover
  check(
    vim.wait(20000, function()
      hover = tailwind:request_sync("textDocument/hover", {
        textDocument = { uri = vim.uri_from_bufnr(buf) },
        position = { line = 0, character = 44 },
      }, 1000, buf)
      return hover and hover.result and hover.result.contents
    end, 100),
    "Tailwind v4 class hover"
  )
  local completion = tailwind:request_sync("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = 0, character = 44 },
  }, 10000, buf)
  check(
    completion and completion.result and #(completion.result.items or completion.result) > 0,
    "Tailwind class completion"
  )
  local original = lines(buf)
  vim.cmd.write()
  check(lines(buf) == original, "No-policy TSX formatted on save")
  vim.cmd("Format")
  check(
    vim.wait(5000, function()
      return lines(buf) ~= original
    end, 20),
    "Manual TSX formatting"
  )
  check(table.concat(vim.fn.readfile(root .. "/src/App.tsx"), "\n") == original, "Manual formatting wrote the file")
  local jsx = open(root .. "/src/Other.jsx")
  client("vtsls", jsx)
  check(vim.treesitter.get_parser(jsx):lang() == "javascript", "JSX parser")

  root = fixture("prettier", {
    [".prettierrc.json"] = '{"semi":false,"singleQuote":true}',
    [".prettierignore"] = "ignored.js",
    ["main.js"] = 'export const x={ a:"hello" };',
    ["ignored.js"] = 'export const x={ a:"hello" };',
  })
  buf = open(root .. "/main.js")
  vim.cmd.write()
  check(lines(buf) == "export const x = { a: 'hello' }", "Project Prettier settings not applied: " .. lines(buf))
  check(
    require("conform").get_formatter_info("prettier", buf).command == root .. "/node_modules/.bin/prettier",
    "Local Prettier not selected"
  )
  buf = open(root .. "/ignored.js")
  original = lines(buf)
  vim.cmd.write()
  check(lines(buf) == original, "Prettier ignore not respected")

  root = fixture("biome", {
    ["biome.jsonc"] = '{ // JSONC stays with Biome\n "formatter":{"indentStyle":"space","indentWidth":2}, "files":{"includes":["**","!**/ignored.js"]},\n}',
    ["main.js"] = "debugger;\nexport const x={ a:1 };",
    ["ignored.js"] = "export const x={ a:1 };",
  })
  buf = open(root .. "/main.js")
  local biome = client("biome", buf)
  diagnostic(buf, "debugger")
  local actions = biome:request_sync("textDocument/codeAction", {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 9 } },
    context = { diagnostics = {} },
  }, 10000, buf)
  check(actions and actions.result and #actions.result > 0, "Biome code actions")
  vim.cmd.write()
  check(lines(buf):find("a: 1", 1, true), "Biome formatting missing")
  check(lines(buf):find("debugger;", 1, true), "Formatting unexpectedly applied a lint fix")
  buf = open(root .. "/ignored.js")
  original = lines(buf)
  vim.cmd.write()
  check(lines(buf) == original, "Biome ignore not respected")
  write(root .. "/biome.jsonc", '{"formatter":{"enabled":false}}')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "export const x={ a:2 };" })
  original = lines(buf)
  vim.cmd.write()
  check(lines(buf) == original, "Disabled Biome formatter modified the buffer")
  write(root .. "/.prettierrc", '{"semi":false}')
  check(
    require("config.formatting.typescript").select(root .. "/main.js", false).formatter == "prettier",
    "Lint-only Biome conflicted with Prettier"
  )

  root = fixture("nested-biome", {
    ["packages/app/package.json"] = "{}",
    ["packages/app/biome.jsonc"] = '{"javascript":{"formatter":{"quoteStyle":"single"}}}',
    ["packages/app/main.js"] = 'export const value="nested";',
  })
  buf = open(root .. "/packages/app/main.js")
  local nested_biome = client("biome", buf)
  check(nested_biome.config.root_dir == root .. "/packages/app", "Nested Biome LSP root")
  vim.cmd.write()
  check(lines(buf) == "export const value = 'nested';", "Nested Biome configuration not used")

  root = fixture("eslint", {
    ["eslint.config.mjs"] = 'export default [{ rules: { "no-debugger": "error" } }];',
    ["main.js"] = "debugger;\nexport const value=1;",
  })
  buf = open(root .. "/main.js")
  local eslint = client("eslint", buf)
  diagnostic(buf, "debugger")
  actions = eslint:request_sync("textDocument/codeAction", {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 9 } },
    context = { diagnostics = {}, only = { "source.fixAll.eslint" } },
  }, 10000, buf)
  check(actions and actions.result and #actions.result > 0, "ESLint code actions")
  original = lines(buf)
  vim.cmd.write()
  check(lines(buf) == original, "ESLint-only project formatted/fixed on save")
  check(eslint.config.settings.workingDirectory.mode == "auto", "ESLint working directory")
end, debug.traceback)
for _, c in ipairs(vim.lsp.get_clients()) do
  c:stop(true)
end
vim.fn.delete(tmp, "rf")
if not ok then
  print(err)
  vim.cmd("cquit 1")
end
print("TypeScript integration: " .. count .. " assertions passed")
