require("mason").setup()

local python = require("config.python")
python.setup()
require("config.python.ruff").setup()

-- Rustaceanvim starts rust-analyzer itself, using the installed Rust toolchain.
-- Keep rust_analyzer out of Mason's enable list to avoid a second LSP client.
-- Toolchain components: rustup component add rust-analyzer rust-src rustfmt clippy

-- Install all supported servers up front. Root callbacks select one Python
-- typechecker per project and independently opt into Ruff linting.
local servers = vim.list_extend({ "lua_ls", "ruff" }, python.servers)

require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_enable = servers,
})
