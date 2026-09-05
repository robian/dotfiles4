local get = require("util.project").get

return {
  name = "ruff",
  formatter = "ruff_format",
  package = "ruff",
  markers = { ".ruff.toml", "ruff.toml" },
  detect = function(context)
    -- Ruff's config precedence is .ruff.toml > ruff.toml > pyproject.toml.
    -- General/lint settings alone don't establish a formatting policy.
    local settings
    if context.exists(".ruff.toml") then
      settings = context.read(".ruff.toml")
    elseif context.exists("ruff.toml") then
      settings = context.read("ruff.toml")
    else
      settings = get(context.data, "tool", "ruff") or {}
    end
    return settings.format ~= nil
  end,
}
