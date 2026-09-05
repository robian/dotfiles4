local project = require("util.project")
local python_project = require("config.python.project")

-- Add a checker here to register its detection, project markers, installation
-- and LSP setup. Each module provides name, markers, detect(project),
-- environment_configured(project), and settings(python_path).
local checkers = {
  require("config.python.ty"),
  require("config.python.basedpyright"),
  require("config.python.pyright"),
}
local fallback = "pyright"
local M = { servers = {} }
local by_name = {}
local markers = vim.deepcopy(python_project.markers)
for _, checker in ipairs(checkers) do
  by_name[checker.name] = checker
  M.servers[#M.servers + 1] = checker.name
  for _, marker in ipairs(checker.markers) do
    if not vim.tbl_contains(markers, marker) then
      markers[#markers + 1] = marker
    end
  end
end

-- Selection strategy, independently for each edited file's nearest project:
-- 1. No project marker means the fallback server in standalone mode (no root),
--    matching nvim-lspconfig/LazyVim. Nested projects don't inherit a parent's
--    server choice; shared virtual environments may still be reused.
-- 2. Optional .nvim.json: {"python":{"server":"ty","venv":".venv"}}.
--    This is our data-only editor override, not a cross-editor standard.
-- 3. Ask every checker to detect its own configuration/direct dependencies.
--    Order is deterministic but NOT priority: multiple matches are an error,
--    resolved by an explicit server override. No matches uses the fallback.
--    Locks and installed executables never select a checker.
-- Restart Neovim after changing selection/environment config to detach any
-- already-running server. :PythonLspInfo reports selection and active clients.
function M.select(filename)
  local root = project.root(filename, markers)
  if not root then
    return { server = fallback, reason = "Standalone file (no project root)" }
  end
  local override = project.get(project.read(vim.fs.joinpath(root, ".nvim.json")), "python") or {}
  if type(override) ~= "table" then
    error(root .. ": .nvim.json python must be an object")
  end
  if override.server ~= nil and not by_name[override.server] then
    error(root .. ": python.server must be one of " .. table.concat(M.servers, ", "))
  end

  local context = python_project.new(root)
  local checker, reason = by_name[override.server], "project override"
  if not checker then
    local matches = {}
    for _, candidate in ipairs(checkers) do
      if candidate.detect(context) then
        matches[#matches + 1] = candidate.name
      end
    end
    table.sort(matches)
    if #matches > 1 then
      error(
        root .. ": conflicting Python servers (" .. table.concat(matches, ", ") .. "). Set python.server in .nvim.json"
      )
    end
    checker = by_name[matches[1] or fallback]
    reason = matches[1] and "project tool configuration/dependency" or "Pyright default (no unambiguous alternative)"
  end

  return {
    root = root,
    server = checker.name,
    reason = reason,
    python = python_project.python(context, checker, override.venv),
  }
end

function M.setup()
  for _, checker in ipairs(checkers) do
    vim.lsp.config(checker.name, {
      settings = {},
      -- Installation/enabling is global; attachment is gated per buffer/root.
      root_dir = function(bufnr, on_dir)
        local ok, selected = pcall(M.select, vim.api.nvim_buf_get_name(bufnr))
        if not ok then
          vim.notify_once(tostring(selected), vim.log.levels.WARN, { title = "Python LSP" })
        elseif selected.server == checker.name then
          on_dir(selected.root)
        end
      end,
      before_init = function(_, config)
        if not config.root_dir then
          return -- standalone files have no project environment to configure
        end
        local selected = M.select(vim.fs.joinpath(config.root_dir, "__nvim_lsp__.py"))
        if selected.python then
          local settings = checker.settings(selected.python)
          -- The LSP client already holds a reference to this settings table by
          -- before_init. Mutate it in place so workspace/configuration replies
          -- include the interpreter; replacing config.settings loses that link.
          for key, value in pairs(settings) do
            config.settings[key] = vim.tbl_deep_extend("force", config.settings[key] or {}, value)
          end
        end
      end,
    })
  end

  vim.api.nvim_create_user_command("PythonLspInfo", function()
    local ok, selected = pcall(M.select, vim.api.nvim_buf_get_name(0))
    if not ok then
      vim.notify(tostring(selected), vim.log.levels.WARN)
      return
    end
    selected.root = selected.root or "standalone (no project root)"
    selected.python = selected.python or "server/project environment discovery"
    selected.active = vim.tbl_map(function(client)
      return client.name
    end, vim.lsp.get_clients({ bufnr = 0 }))
    vim.print(selected)
  end, { desc = "Show this project's Python server selection and environment" })
end

return M
