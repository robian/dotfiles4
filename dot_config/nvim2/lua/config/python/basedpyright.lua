local get = require("util.project").get
local pyright = require("config.python.pyright")

return {
  name = "basedpyright",
  markers = pyright.markers,
  detect = function(project)
    return project.has_dependency("basedpyright") or get(project.data, "tool", "basedpyright")
  end,
  environment_configured = function(project)
    return pyright.environment_configured(project, "basedpyright")
  end,
  settings = pyright.settings,
}
