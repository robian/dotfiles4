local project = require("util.project")
-- rustfmt comes from rustup, alongside the compiler, rather than Mason.
local M = { tools = {} }
local markers = { "Cargo.toml", "rustfmt.toml", ".rustfmt.toml" }

-- Cargo projects use rustfmt on save, even without a formatting config.
-- Explicit :Format also works for standalone buffers. Use normal Rust defaults;
-- dependency sources follow the same rules as other Cargo projects.
function M.select(filename, manual)
  local root = filename ~= "" and project.root(filename, markers) or nil
  local policy = root ~= nil
    and vim.iter(markers):any(function(marker)
      return project.exists(vim.fs.joinpath(root, marker))
    end)
  if policy or manual then
    return { formatter = "rustfmt", root = root, policy = policy }
  end
end

M.formatters = {
  rustfmt = {
    -- Resolve rustup toolchain overrides and rustfmt config from the file's
    -- directory, including when Neovim was launched in a different project.
    cwd = function(_, ctx)
      return ctx.dirname
    end,
  },
}

return M
