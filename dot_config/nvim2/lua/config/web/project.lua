local project = require("util.project")
local M = {}
local locks = { "pnpm-workspace.yaml", "pnpm-lock.yaml", "package-lock.json", "yarn.lock", "bun.lock", "bun.lockb" }

-- Start at the edited file. Shared configs/tools may live above a package in
-- a monorepo, but never search beyond its Git/workspace boundary or into home.
function M.new(filename)
  local dir = filename ~= "" and vim.fs.dirname(vim.fs.abspath(filename)) or vim.fn.getcwd()
  local nearest = project.root(vim.fs.joinpath(dir, "__web__"), {
    "package.json",
    "tsconfig.json",
    "jsconfig.json",
    "biome.json",
    "biome.jsonc",
    ".nvim.json",
  })
  local git = vim.fs.root(dir, { ".git" })
  local workspace = vim.fs.root(dir, locks)
  if git and workspace and #workspace < #git then
    workspace = nil
  end
  local root = workspace or git or nearest
  local context = { root = root, dirs = {}, filename = filename }
  local boundary = root or dir
  while dir do
    context.dirs[#context.dirs + 1] = dir
    if dir == boundary or dir == vim.uv.os_homedir() then
      break
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  function context.find(names)
    for _, directory in ipairs(context.dirs) do
      for _, name in ipairs(names) do
        local path = vim.fs.joinpath(directory, name)
        if project.exists(path) then
          return path
        end
      end
    end
  end
  function context.package_field(name)
    for _, directory in ipairs(context.dirs) do
      local value = project.read(vim.fs.joinpath(directory, "package.json"))[name]
      if value ~= nil then
        return value, directory
      end
    end
  end
  function context.dependency(name)
    for _, directory in ipairs(context.dirs) do
      local data = project.read(vim.fs.joinpath(directory, "package.json"))
      for _, group in ipairs({ "dependencies", "devDependencies", "peerDependencies", "optionalDependencies" }) do
        if project.get(data, group, name) then
          return true
        end
      end
    end
    return false
  end
  function context.command(name)
    for _, directory in ipairs(context.dirs) do
      local path = vim.fs.joinpath(directory, "node_modules", ".bin", name)
      if vim.fn.executable(path) == 1 then
        return path
      end
    end
    return name -- Mason's bin directory is on PATH.
  end
  return context
end

return M
