local get = require("util.project").get

return {
  name = "ty",
  markers = { "ty.toml" },
  detect = function(project)
    return project.has_dependency("ty") or project.exists("ty.toml") or get(project.data, "tool", "ty")
  end,
  environment_configured = function(project)
    local settings = project.exists("ty.toml") and project.read("ty.toml") or get(project.data, "tool", "ty") or {}
    return get(settings, "environment", "python") or settings.extends
  end,
  settings = function(python_path)
    return { ty = { configuration = { environment = { python = python_path } } } }
  end,
}
