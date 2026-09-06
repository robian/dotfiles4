-- nvim --headless -u NONE -i NONE -l ~/.config/nvim2/tests/formatting.lua
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
local python = require("config.formatting.python")
local lua = require("config.formatting.lua")
local tmp = vim.fn.tempname()
local count = 0
local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(contents, "\n"), path)
end
local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
  count = count + 1
end
local function fails(fn)
  equal(pcall(fn), false)
end

local ok, err = xpcall(function()
  local cases = {
    { {}, nil },
    { { ["pyproject.toml"] = '[project]\ndependencies=["ruff", "black"]' }, nil },
    { { ["pyproject.toml"] = "[tool.ruff]\nline-length=100" }, nil },
    { { ["ruff.toml"] = '[lint]\nselect=["E"]' }, nil },
    { { ["pyproject.toml"] = "[tool.black]" }, nil },
    { { ["pyproject.toml"] = "[tool.ruff.format]" }, "ruff_format" },
    { { ["ruff.toml"] = "[format]" }, "ruff_format" },
    { { [".ruff.toml"] = "[format]" }, "ruff_format" },
    { { ["pyproject.toml"] = "[tool.black]\n[tool.ruff.lint]" }, nil },
    { { ["pyproject.toml"] = "[tool.black]\n[tool.ruff.format]" }, "ruff_format" },
    -- The higher-priority Ruff file shadows lower-priority format settings.
    { { ["pyproject.toml"] = "[tool.ruff.format]", ["ruff.toml"] = "[lint]" }, nil },
    { { ["ruff.toml"] = "[format]", [".ruff.toml"] = "[lint]" }, nil },
    { { [".nvim.json"] = '{"python":{"formatter":"ruff"}}' }, "ruff_format" },
  }
  for i, case in ipairs(cases) do
    local root = tmp .. "/case" .. i
    vim.fn.mkdir(root, "p")
    for name, contents in pairs(case[1]) do
      write(root .. "/" .. name, contents)
    end
    local choice = python.select(root .. "/main.py", false)
    equal(choice and choice.formatter, case[2])
    equal(python.select(root .. "/main.py", true).formatter, case[2] or "ruff_format")
  end
  local root = tmp .. "/override"
  write(root .. "/.nvim.json", '{"python":{"formatter":"black"}}')
  fails(function()
    python.select(root .. "/main.py", false)
  end)
  fails(function()
    python.select(root .. "/main.py", true)
  end)
  write(root .. "/.nvim.json", '{"python":{"formatter":"ruff"}}')
  equal(python.select(root .. "/main.py", false).formatter, "ruff_format")
  write(root .. "/.nvim.json", '{"python":{"formatter":false}}')
  equal(python.select(root .. "/main.py", false).disabled, true)
  equal(python.select(root .. "/main.py", true).disabled, true)
  write(root .. "/.nvim.json", '{"python":{"formatter":"unknown"}}')
  fails(function()
    python.select(root .. "/main.py", true)
  end)
  write(root .. "/.nvim.json", "{")
  fails(function()
    python.select(root .. "/main.py", true)
  end)
  local malformed = tmp .. "/malformed"
  write(malformed .. "/pyproject.toml", "[broken")
  fails(function()
    python.select(malformed .. "/main.py", true)
  end)

  local mono = tmp .. "/mono"
  vim.fn.mkdir(mono .. "/.git", "p")
  write(mono .. "/pyproject.toml", "[tool.ruff.format]")
  write(mono .. "/child/pyproject.toml", "[project]")
  equal(python.select(mono .. "/child/main.py", false), nil)
  vim.fn.chdir(mono)
  equal(python.select(tmp .. "/standalone.py", false), nil)
  equal(python.select("", true).formatter, "ruff_format")

  local function executable(path)
    write(path, "#!/bin/sh\nexit 0")
    vim.fn.setfperm(path, "rwx------")
  end
  executable(mono .. "/.venv/bin/ruff")
  local command = python.command("ruff")
  equal(command(nil, { filename = mono .. "/child/main.py" }), mono .. "/.venv/bin/ruff")
  vim.fn.mkdir(mono .. "/child/.git", "p")
  equal(command(nil, { filename = mono .. "/child/main.py" }), "ruff")
  executable(mono .. "/custom/bin/ruff")
  write(mono .. "/.nvim.json", '{"python":{"venv":"custom"}}')
  equal(command(nil, { filename = mono .. "/main.py" }), mono .. "/custom/bin/ruff")

  equal(lua.select(tmp .. "/plain.lua", false), nil)
  equal(lua.select(tmp .. "/plain.lua", true).formatter, "stylua")
  write(tmp .. "/lua/stylua.toml", "indent_width = 2")
  equal(lua.select(tmp .. "/lua/main.lua", false).formatter, "stylua")
end, debug.traceback)
vim.fn.chdir(config)
vim.fn.delete(tmp, "rf")
assert(ok, err)
print("Formatting policy: " .. count .. " assertions passed")
