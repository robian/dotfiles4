require("mason").setup()

local python = require("config.python")
python.setup()
require("config.python.ruff").setup()

-- Install all supported servers up front. Root callbacks select one Python
-- typechecker per project and independently opt into Ruff linting.
local servers = vim.list_extend({ "lua_ls", "ruff" }, python.servers)

require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_enable = servers,
})
