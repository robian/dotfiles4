local get = require("util.project").get
local M = { name = "pyright", markers = { "pyrightconfig.json" } }

function M.detect(project)
  local package = project.read("package.json")
  -- pyrightconfig.json and [tool.pyright] are also supported by basedpyright.
  -- They don't select Pyright over another checker; Pyright is the fallback.
  return project.has_dependency("pyright")
    or get(package, "dependencies", "pyright")
    or get(package, "devDependencies", "pyright")
end

-- Shared with basedpyright. Delegate JSONC/extends to the server instead of
-- trying to interpret inherited environment settings ourselves.
function M.environment_configured(project, name)
  local settings = get(project.data, "tool", name or M.name) or get(project.data, "tool", "pyright") or {}
  return settings.venv or settings.venvPath or settings.extends or project.exists("pyrightconfig.json")
end

function M.settings(python_path)
  return { python = { pythonPath = python_path } }
end

return M
