local project = require("util.project")
local M = { tools = { { package = "stylua" } } }
local markers = { ".stylua.toml", "stylua.toml" }

function M.select(filename, manual)
  local root = filename ~= "" and project.root(filename, markers) or nil
  local policy = root
    and (project.exists(vim.fs.joinpath(root, markers[1])) or project.exists(vim.fs.joinpath(root, markers[2])))
  if policy or manual then
    return { formatter = "stylua", root = root, policy = policy or false }
  end
end

return M
