local project = require("util.project")
local M = {}
local requirements = { "requirements.txt", "requirements-dev.txt", "requirements.in", "requirements-dev.in" }
M.markers = vim.list_extend({ "pyproject.toml", ".nvim.json", "setup.py", "setup.cfg", "Pipfile" }, requirements)

-- Collect direct dependency declarations, independently of which checkers are
-- registered. No locks, installed executables, dynamic setup.py, Pipfile/CI
-- parsing or -r includes. Groups/extras/markers are declarations, not evaluated
-- against this machine. All PEP 735 groups are scanned, including included ones.
local function dependencies(context)
  local found = {}
  local function add(requirement)
    if type(requirement) ~= "string" then
      return
    end
    local name = requirement:match("^%s*([%w_.-]+)")
    if name then
      found[name:lower():gsub("[_.-]+", "-")] = true
    end
  end
  local function list(items)
    for _, requirement in ipairs(items or {}) do
      add(requirement)
    end
  end
  local function keys(items)
    for name in pairs(items or {}) do
      add(name)
    end
  end

  local data = context.data
  list(project.get(data, "project", "dependencies"))
  for _, items in pairs(project.get(data, "project", "optional-dependencies") or {}) do
    list(items)
  end
  for _, items in pairs(data["dependency-groups"] or {}) do
    list(items)
  end
  list(project.get(data, "tool", "uv", "dev-dependencies"))
  local poetry = project.get(data, "tool", "poetry") or {}
  keys(poetry.dependencies)
  keys(poetry["dev-dependencies"])
  for _, group in pairs(poetry.group or {}) do
    keys(group.dependencies)
  end
  for _, filename in ipairs(requirements) do
    if context.exists(filename) then
      list(vim.fn.readfile(vim.fs.joinpath(context.root, filename)))
    end
  end
  return found
end

-- Each detector receives this same context. File reads use the shared cache;
-- dependency extraction runs at most once per selection, and not for overrides.
function M.new(root)
  local context = { root = root }
  function context.read(filename)
    return project.read(vim.fs.joinpath(root, filename))
  end
  function context.exists(filename)
    return project.exists(vim.fs.joinpath(root, filename))
  end
  local declared
  function context.has_dependency(name)
    declared = declared or dependencies(context)
    return declared[name] == true
  end
  context.data = context.read("pyproject.toml")
  return context
end

local function interpreter(environment)
  for _, relative in ipairs({ "bin/python", "bin/python3", "Scripts/python.exe" }) do
    local path = vim.fs.joinpath(environment, relative)
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
end

-- Explicit override first, then the checker's own environment settings, then
-- .venv/venv discovery. A monorepo may share an environment up to its Git root.
-- Without a Git boundary, search only the project directory. Returning nil
-- leaves native server discovery (including an activated environment) intact.
function M.python(context, checker, venv)
  local root = context.root
  if venv ~= nil then
    if type(venv) ~= "string" or venv == "" then
      error(root .. ": python.venv must be an environment directory")
    end
    local environment = vim.fs.abspath(vim.fs.joinpath(root, venv))
    if vim.startswith(venv, "/") or venv:match("^%a:[/\\]") then
      environment = venv
    end
    local python = interpreter(environment)
    if not python then
      error("No Python executable in environment: " .. environment)
    end
    return python
  end
  if checker.environment_configured(context) then
    return nil
  end
  local boundary = vim.fs.root(root, { ".git" }) or root
  local dir = root
  while dir do
    for _, name in ipairs({ ".venv", "venv" }) do
      local python = interpreter(vim.fs.joinpath(dir, name))
      if python then
        return python
      end
    end
    if dir == boundary then
      break
    end
    dir = vim.fs.dirname(dir)
  end
end

return M
