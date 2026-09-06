local project = require("util.project")
local python_project = require("config.python.project")
local ruff = require("config.formatting.python.ruff")
local M = { tools = { ruff } }
local markers = vim.deepcopy(python_project.markers)
-- Typechecker-only projects are still boundaries for formatting policy.
vim.list_extend(markers, { "pyrightconfig.json", "ty.toml" })
vim.list_extend(markers, ruff.markers)

-- Saving requires formatter-specific project configuration or an explicit
-- .nvim.json override: {"python":{"formatter":"ruff"}} (or false to disable).
-- Dependencies, locks, generic Ruff/lint settings and installed tools are not
-- formatting policy. We don't infer policy from CI/pre-commit or resolve Ruff
-- extends ourselves; an override can express policy that lives there.
-- The nearest project wins; no policy never enables formatting on save.
-- :Format may fall back to Ruff, but never bypasses invalid overrides or false.
function M.select(filename, manual)
  local root = filename ~= "" and project.root(filename, markers) or nil
  local policy = false
  if root then
    local override = project.get(project.read(vim.fs.joinpath(root, ".nvim.json")), "python") or {}
    if type(override) ~= "table" then
      error(root .. ": .nvim.json python must be an object")
    end
    if override.formatter == false then
      return { disabled = true, root = root, reason = "Python formatting is disabled in .nvim.json" }
    elseif override.formatter ~= nil then
      if override.formatter ~= "ruff" then
        error(root .. ": python.formatter must be ruff or false")
      end
      policy = true
    else
      policy = ruff.detect(python_project.new(root))
    end
  end
  if policy or manual then
    return { formatter = ruff.formatter, root = root, policy = policy }
  end
end

-- Prefer a project executable, including a shared monorepo environment, then
-- PATH (Mason prepends its bin directory). Respect our explicit venv override.
function M.command(name)
  return function(_, ctx)
    local root = ctx.filename ~= "" and project.root(ctx.filename, markers) or nil
    if not root then
      return name
    end
    local override = project.get(project.read(vim.fs.joinpath(root, ".nvim.json")), "python", "venv")
    local function executable(environment)
      for _, path in ipairs({ "bin/" .. name, "Scripts/" .. name .. ".exe" }) do
        local candidate = vim.fs.joinpath(environment, path)
        if vim.fn.executable(candidate) == 1 then
          return candidate
        end
      end
    end
    if override ~= nil then
      if type(override) ~= "string" or override == "" then
        error(root .. ": python.venv must be an environment directory")
      end
      local environment = override
      if not vim.startswith(override, "/") and not override:match("^%a:[/\\]") then
        environment = vim.fs.joinpath(root, override)
      end
      return executable(environment) or name
    end
    local boundary = vim.fs.root(root, { ".git" }) or root
    local dir = root
    while dir do
      for _, venv in ipairs({ ".venv", "venv" }) do
        local found = executable(vim.fs.joinpath(dir, venv))
        if found then
          return found
        end
      end
      if dir == boundary then
        break
      end
      dir = vim.fs.dirname(dir)
    end
    return name
  end
end

M.formatters = { [ruff.formatter] = { command = M.command(ruff.name) } }

return M
