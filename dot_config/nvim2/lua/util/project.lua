local M = {}
local cache = {}

local navigation_markers = {
  ".nvim.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "Cargo.toml",
  "package.json",
}

function M.exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

-- Search from the edited file, never from :pwd. A nearer manifest wins over
-- a parent manifest, and a .git directory/file stops the search at a repository
-- boundary. No marker means no project root: let LSP use standalone mode.
function M.root(filename, markers)
  assert(filename ~= "", "Project detection requires a named file")
  local start = vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(filename, ":p")))
  local dir = start
  while dir do
    for _, marker in ipairs(markers) do
      if M.exists(vim.fs.joinpath(dir, marker)) then
        return dir
      end
    end
    if M.exists(vim.fs.joinpath(dir, ".git")) then
      return dir
    end
    if dir == vim.uv.os_homedir() then
      return nil
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break -- dirname("/") is "/", not nil
    end
    dir = parent
  end
  return nil
end

-- Use the edited file's nearest project marker or Git boundary. For a
-- standalone file, browse its directory; an unnamed buffer starts at :pwd.
function M.navigation_root(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr or 0)
  if filename == "" then
    filename = vim.fs.joinpath(vim.fn.getcwd(), "__navigation__")
  end
  return M.root(filename, navigation_markers) or vim.fs.dirname(filename)
end

-- Read data only: never source project Lua or execute pyproject/build scripts.
-- TOML is parsed in-process by the vendored Lua library; JSON uses Neovim.
-- Cache by file metadata so the three server callbacks do not repeat parsing.
-- Missing files are empty tables; malformed files raise an actionable error.
function M.read(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    cache[path] = nil
    return {}
  end
  local stamp = table.concat({ stat.size, stat.mtime.sec, stat.mtime.nsec, stat.ctime.sec, stat.ctime.nsec }, ":")
  if cache[path] and cache[path].stamp == stamp then
    return cache[path].data
  end

  local ok, data
  if path:sub(-5) == ".toml" then
    ok, data = pcall(require("vendor.tinytoml").parse, path)
    if not ok then
      error("Cannot parse " .. path .. ": " .. tostring(data))
    end
  else
    local contents = table.concat(vim.fn.readfile(path), "\n")
    ok, data = pcall(vim.json.decode, contents, { luanil = { object = true, array = true } })
  end
  if not ok or type(data) ~= "table" then
    error("Invalid configuration in " .. path .. ": expected a JSON/TOML object")
  end
  cache[path] = { stamp = stamp, data = data }
  return data
end

function M.get(data, ...)
  for _, key in ipairs({ ... }) do
    if type(data) ~= "table" then
      return nil
    end
    data = data[key]
  end
  return data
end

return M
