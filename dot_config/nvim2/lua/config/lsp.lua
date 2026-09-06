require("mason").setup()

-- Show hints from supporting servers in existing and newly opened buffers.
vim.lsp.inlay_hint.enable(true)

local python = require("config.python")
python.setup()
require("config.python.ruff").setup()

-- Rustaceanvim starts rust-analyzer itself, using the installed Rust toolchain.
-- Keep rust_analyzer out of Mason's enable list to avoid a second LSP client.
-- Toolchain components: rustup component add rust-analyzer rust-src rustfmt clippy

-- Install all supported servers up front. Root callbacks select one Python
-- typechecker per project and independently opt into Ruff linting.
local servers = vim.list_extend({ "lua_ls", "ruff" }, python.servers)
local web = require("config.web")
web.setup()
vim.list_extend(servers, web.servers)

require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_enable = servers,
})
