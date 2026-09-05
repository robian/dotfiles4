local project = require("util.project")
local python_project = require("config.python.project")
local M = {
  tools = {
    require("config.formatting.python.ruff"),
    require("config.formatting.python.black"),
  },
}
local by_name = {}
local markers = vim.deepcopy(python_project.markers)
-- Typechecker-only projects are still boundaries for formatting policy.
vim.list_extend(markers, { "pyrightconfig.json", "ty.toml" })
for _, tool in ipairs(M.tools) do
  by_name[tool.name] = tool
  vim.list_extend(markers, tool.markers)
end

-- Saving requires formatter-specific project configuration or an explicit
-- .nvim.json override: {"python":{"formatter":"ruff"}} (also "black"/false).
-- Dependencies, locks, generic Ruff/lint settings and installed tools are not
-- formatting policy. We don't infer policy from CI/pre-commit or resolve Ruff
-- extends ourselves; an override can express policy that lives there.
-- The nearest project wins; no policy never enables formatting on save.
-- :Format may fall back to Ruff, but never bypasses conflicts or explicit false.
function M.select(filename, manual)
  local root = filename ~= "" and project.root(filename, markers) or nil
  local choice
  if root then
    local override = project.get(project.read(vim.fs.joinpath(root, ".nvim.json")), "python") or {}
    if type(override) ~= "table" then
      error(root .. ": .nvim.json python must be an object")
    end
    if override.formatter == false then
      return { disabled = true, root = root, reason = "Python formatting is disabled in .nvim.json" }
    elseif override.formatter ~= nil then
      choice = by_name[override.formatter]
      if not choice then
        error(root .. ": python.formatter must be ruff, black or false")
      end
    else
      local context = python_project.new(root)
      local matches = {}
      for _, tool in ipairs(M.tools) do
        if tool.detect(context) then
          matches[#matches + 1] = tool.name
        end
      end
      if #matches > 1 then
        error(root .. ": conflicting Python formatters; set python.formatter in .nvim.json")
      end
      choice = by_name[matches[1]]
    end
  end
  local policy = choice ~= nil
  choice = choice or (manual and by_name.ruff or nil)
  if choice then
    return { formatter = choice.formatter, root = root, policy = policy }
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

M.formatters = {}
for _, tool in ipairs(M.tools) do
  M.formatters[tool.formatter] = { command = M.command(tool.name) }
end

return M
