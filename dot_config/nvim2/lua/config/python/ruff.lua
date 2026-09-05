local project = require("util.project")
local python_project = require("config.python.project")
local M = {}
local markers = vim.list_extend(vim.deepcopy(python_project.markers), {
  "pyrightconfig.json",
  "ty.toml",
  "ruff.toml",
  ".ruff.toml",
})

-- Linting is independent of typechecker and formatter selection. Standalone
-- files use Ruff; projects opt in through Ruff config or a direct dependency.
-- The nearest project wins, so a nested project doesn't inherit this opt-in.
-- Ruff itself reads the rules/exclusions; lint evidence is NOT format policy.
function M.select(filename)
  local root = project.root(filename, markers)
  if not root then
    return { enabled = true } -- retain native standalone mode (no root)
  end
  local context = python_project.new(root)
  return {
    root = root,
    enabled = context.exists(".ruff.toml")
      or context.exists("ruff.toml")
      or project.get(context.data, "tool", "ruff") ~= nil
      or context.has_dependency("ruff"),
  }
end

function M.setup()
  vim.lsp.config("ruff", {
    root_dir = function(bufnr, on_dir)
      local ok, selected = pcall(M.select, vim.api.nvim_buf_get_name(bufnr))
      if not ok then
        vim.notify_once(tostring(selected), vim.log.levels.WARN, { title = "Ruff LSP" })
      elseif selected.enabled then
        on_dir(selected.root)
      end
    end,
    init_options = { settings = { logLevel = "error" } },
    on_attach = function(client)
      -- Keep hover with the typechecker and formatting with Conform's policy.
      -- Diagnostics and explicit code actions remain available; no save fixes.
      client.server_capabilities.hoverProvider = false
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
  })
end

return M
