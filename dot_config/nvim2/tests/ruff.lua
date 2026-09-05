-- nvim --headless -u NONE -i NONE -l ~/.config/nvim2/tests/ruff.lua
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
local ruff = require("config.python.ruff")
local formatting = require("config.formatting.python")
local tmp = vim.fn.tempname()
local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(contents, "\n"), path)
end
local ok, err = xpcall(function()
  vim.fn.mkdir(tmp, "p")
  local standalone = ruff.select(tmp .. "/main.py")
  assert(standalone.enabled and standalone.root == nil)
  local cases = {
    { "pyproject.toml", "[project]", false },
    { "pyrightconfig.json", "{}", false },
    { "ty.toml", "", false },
    { "setup.cfg", "", false },
    { "pyproject.toml", '[project]\ndependencies=["pylint"]', false },
    { "pyproject.toml", '[dependency-groups]\ndev=["ruff>=0.16"]', true },
    { "requirements-dev.txt", "ruff==0.16.6", true },
    { "ruff.toml", "", true },
    { ".ruff.toml", '[lint]\nselect=["F401"]', true },
    { "pyproject.toml", "[tool.ruff]", true },
    { "pyproject.toml", '[tool.ruff.lint]\nselect=["F401"]', true },
  }
  for i, case in ipairs(cases) do
    local root = tmp .. "/case" .. i
    write(root .. "/" .. case[1], case[2])
    local file = root .. "/main.py"
    local selected = ruff.select(file)
    assert(selected.enabled == case[3] and selected.root == root, "case " .. i)
    assert(formatting.select(file, false) == nil, "Lint evidence enabled formatting")
  end
  write(tmp .. "/parent/ruff.toml", "")
  write(tmp .. "/parent/child/pyproject.toml", "[project]")
  assert(not ruff.select(tmp .. "/parent/child/main.py").enabled)
  vim.fn.mkdir(tmp .. "/git/.git", "p")
  assert(not ruff.select(tmp .. "/git/main.py").enabled)
  write(tmp .. "/broken/pyproject.toml", "[broken")
  assert(not pcall(ruff.select, tmp .. "/broken/main.py"))
end, debug.traceback)
vim.fn.delete(tmp, "rf")
assert(ok, err)
print("Ruff selection: standalone, project evidence, boundaries and formatting policy passed")
