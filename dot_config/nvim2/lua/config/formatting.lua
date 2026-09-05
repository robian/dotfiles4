local tools = { "stylua" }
local registry = require("mason-registry")

registry.refresh(function()
  for _, name in ipairs(tools) do
    local package = registry.get_package(name)

    if not package:is_installed() then
      package:install()
    end
  end
end)

require("conform").setup({
  -- notify_no_formatters = false,
  formatters_by_ft = {
    lua = { "stylua" },
  },
  formatters = {
    stylua = {
      require_cwd = true,
    },
  },
  format_on_save = {
    timeout_ms = 1000,
    lsp_format = "never",
  },
})
