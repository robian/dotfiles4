-- Run without loading/installing plugins:
-- nvim --headless -u NONE -i NONE -l ~/.config/nvim2/tests/python.lua
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
local python = require("config.python")
local project = require("util.project")
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local count = 0

local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(contents, "\n", { plain = true }), path)
end

local function fixture(name, files)
  local root = vim.fs.joinpath(tmp, name)
  vim.fn.mkdir(root .. "/.git", "p")
  for path, contents in pairs(files or {}) do
    write(root .. "/" .. path, contents)
  end
  write(root .. "/src/example.py", "x = 1")
  return root, root .. "/src/example.py"
end

local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect({ expected = expected, actual = actual }))
  count = count + 1
end

local function fails(fn, pattern)
  local ok, message = pcall(fn)
  assert(not ok and tostring(message):find(pattern, 1, true), tostring(message))
  count = count + 1
end

local function environment(root, name)
  local path = root .. "/" .. (name or ".venv") .. "/bin/python"
  write(path, "#!/bin/sh\nexit 0")
  vim.fn.setfperm(path, "rwx------")
  return path
end

local ok, err = xpcall(function()
  local plain, file = fixture("default")
  equal(python.select(file).server, "pyright")
  equal(python.select(file).root, plain)
  write(tmp .. "/standalone/example.py", "x = 1")
  local standalone = tmp .. "/standalone/example.py"
  equal(python.select(standalone).root, nil)
  equal(python.select(standalone).server, "pyright")
  equal(project.root("/unlikely-nvim-test-dir/file.py", {}), nil)
  local _, based = fixture("based", {
    ["pyproject.toml"] = '[dependency-groups]\ndev = [\n "basedpyright>=1", # comment\n]\n[tool.pyright]\ntypeCheckingMode="strict"',
  })
  equal(python.select(based).server, "basedpyright")
  local _, ty = fixture("ty", { ["ty.toml"] = "[environment]\npython-version='3.12'" })
  equal(python.select(ty).server, "ty")
  local _, quoted = fixture("quoted", { ["pyproject.toml"] = '[tool."basedpyright"]\n' })
  equal(python.select(quoted).server, "basedpyright")
  local _, optional = fixture("optional", { ["pyproject.toml"] = '[project.optional-dependencies]\nlint=["ty"]' })
  equal(python.select(optional).server, "ty")
  local _, poetry = fixture("poetry", { ["pyproject.toml"] = '[tool.poetry.group.dev.dependencies]\nbasedpyright="*"' })
  equal(python.select(poetry).server, "basedpyright")
  local _, uv = fixture("uv", { ["pyproject.toml"] = '[tool.uv]\ndev-dependencies=["ty"]' })
  equal(python.select(uv).server, "ty")
  local _, npm = fixture("npm", { ["package.json"] = '{"devDependencies":{"pyright":"*","ty":"*"}}' })
  equal(python.select(npm).server, "pyright")
  local _, requirements = fixture("requirements", { ["requirements-dev.txt"] = "# ty\nbasedpyright==1.0\n" })
  equal(python.select(requirements).server, "basedpyright")
  local _, ignored =
    fixture("ignored", { ["uv.lock"] = 'name="ty"', ["pyproject.toml"] = '# [tool.ty]\n[project]\nname="ty"' })
  equal(python.select(ignored).server, "pyright")
  local _, legacy = fixture("legacy", {
    ["pyrightconfig.json"] = "{ // JSONC is delegated to the server\n}",
    ["pyproject.toml"] = '[project]\ndependencies=["basedpyright"]',
  })
  equal(python.select(legacy).server, "basedpyright")

  local root, conflict = fixture("conflict", { ["pyproject.toml"] = "[tool.ty]\n[tool.basedpyright]\n" })
  fails(function()
    python.select(conflict)
  end, "conflicting Python servers")
  write(root .. "/.nvim.json", '{"python":{"server":"ty"}}')
  equal(python.select(conflict).server, "ty")
  write(root .. "/.nvim.json", '{"python":{"server":"invalid"}}')
  fails(function()
    python.select(conflict)
  end, "python.server must be")
  write(root .. "/.nvim.json", '{"python":{"server":"ty","venv":"missing"}}')
  fails(function()
    python.select(conflict)
  end, "No Python executable")

  local mono = fixture("monorepo", { ["pyproject.toml"] = "[tool.ty]\n" })
  write(mono .. "/packages/a/pyproject.toml", "[tool.basedpyright]\n")
  equal(python.select(mono .. "/packages/a/src/a.py").server, "basedpyright")
  equal(python.select(mono .. "/packages/a/src/a.py").root, mono .. "/packages/a")
  local shared = environment(mono)
  equal(python.select(mono .. "/packages/a/src/a.py").python, shared)
  local nested_python = environment(mono .. "/packages/a")
  equal(python.select(mono .. "/packages/a/src/a.py").python, nested_python)
  vim.fn.mkdir(mono .. "/vendor/b/.git", "p")
  equal(python.select(mono .. "/vendor/b/b.py").server, "pyright")
  equal(python.select(mono .. "/vendor/b/b.py").python, nil)
  vim.fn.chdir(mono)
  equal(python.select(based).server, "basedpyright") -- unrelated :pwd
  equal(python.select(standalone).root, nil)
  equal(python.select(standalone).python, nil) -- don't inherit :pwd's environment

  local envroot, envfile = fixture("environment", { ["pyproject.toml"] = "[tool.ty]\n" })
  local executable = environment(envroot)
  equal(python.select(envfile).python, executable)
  write(envroot .. "/pyproject.toml", '[tool.ty.environment]\npython="custom"')
  equal(python.select(envfile).python, nil) -- preserve ty's explicit environment
  write(envroot .. "/pyproject.toml", '[tool.pyright]\nvenv="custom"\nvenvPath="."')
  equal(python.select(envfile).python, nil)
  write(envroot .. "/.nvim.json", '{"python":{"venv":".venv"}}')
  equal(python.select(envfile).python, executable)
  write(envroot .. "/.nvim.json", vim.json.encode({ python = { venv = envroot .. "/.venv" } }))
  equal(python.select(envfile).python, executable)
  write(envroot .. "/pyproject.toml", "[broken")
  fails(function()
    python.select(envfile)
  end, "Cannot parse")
  write(envroot .. "/pyproject.toml", "[tool.ty]")
  equal(python.select(envfile).server, "ty") -- changed file invalidates cached data
  write(envroot .. "/.nvim.json", "not JSON")
  fails(function()
    python.select(envfile)
  end, "Invalid configuration")
  equal(project.get({ a = { b = true } }, "a", "b"), true)

  -- Exercise the actual Neovim root callbacks and per-client settings. Only
  -- one callback may attach per buffer, even with all three servers enabled.
  python.setup()
  for _, path in ipairs({ file, based, ty, standalone }) do
    local buf = vim.fn.bufadd(path)
    local attached = {}
    for _, name in ipairs(python.servers) do
      vim.lsp.config[name].root_dir(buf, function(dir)
        attached[#attached + 1] = name
        equal(dir, python.select(path).root)
      end)
    end
    equal(attached, { python.select(path).server })
  end
  local settings = { root_dir = plain, settings = { python = { analysis = { diagnosticMode = "openFilesOnly" } } } }
  local original_settings = settings.settings
  local p = environment(plain)
  vim.lsp.config.pyright.before_init({}, settings)
  equal(settings.settings.python.pythonPath, p)
  equal(settings.settings == original_settings, true)
  equal(settings.settings.python.analysis.diagnosticMode, "openFilesOnly")
  local tyroot = vim.fs.dirname(vim.fs.dirname(ty))
  local t = environment(tyroot)
  settings = { root_dir = tyroot, settings = {} }
  vim.lsp.config.ty.before_init({}, settings)
  equal(settings.settings.ty.configuration.environment.python, t)
  settings = { settings = {} }
  vim.lsp.config.pyright.before_init({}, settings)
  equal(settings.settings, {}) -- standalone startup must not inspect :pwd

  -- Replacing a registered module with a new checker should be sufficient:
  -- its name, unique root marker, dependency detection and settings must flow
  -- through the coordinator without any checker-specific branches there.
  local original_ty = package.loaded["config.python.ty"]
  package.loaded["config.python.ty"] = {
    name = "example_checker",
    markers = { "example-checker.toml" },
    detect = function(context)
      return context.exists("example-checker.toml") or context.has_dependency("example-checker")
    end,
    environment_configured = function()
      return false
    end,
    settings = function(path)
      return { example = { interpreter = path } }
    end,
  }
  package.loaded["config.python"] = nil
  local extended = require("config.python")
  local custom = tmp .. "/custom"
  write(custom .. "/example-checker.toml", "") -- no Git/generic project marker
  local custom_python = environment(custom)
  local selected = extended.select(custom .. "/src/main.py")
  equal(selected.root, custom)
  equal(selected.server, "example_checker")
  equal(selected.python, custom_python)
  equal(vim.tbl_contains(extended.servers, "example_checker"), true)
  local _, dependency = fixture("custom-dependency", {
    ["pyproject.toml"] = '[dependency-groups]\ndev=["Example_Checker>=1"]',
  })
  equal(extended.select(dependency).server, "example_checker")
  extended.setup()
  settings = { root_dir = custom, settings = {} }
  vim.lsp.config.example_checker.before_init({}, settings)
  equal(settings.settings.example.interpreter, custom_python)
  local attached = {}
  local buf = vim.fn.bufadd(custom .. "/src/main.py")
  for _, name in ipairs(extended.servers) do
    vim.lsp.config[name].root_dir(buf, function(dir)
      attached[#attached + 1] = name
      equal(dir, custom)
    end)
  end
  equal(attached, { "example_checker" })
  package.loaded["config.python.ty"] = original_ty
  package.loaded["config.python"] = python
end, debug.traceback)

vim.fn.chdir(config)
vim.fn.delete(tmp, "rf")
if not ok then
  error(err)
end
print("Python project selection: " .. count .. " assertions passed")
