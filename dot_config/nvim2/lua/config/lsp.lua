require("mason").setup()

local servers = { "lua_ls" }

require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_enable = servers,
})
