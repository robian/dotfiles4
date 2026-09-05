require("blink.cmp").setup({
  keymap = {
    preset = "enter",
    ["<C-y>"] = { "select_and_accept", "fallback" },
  },
  sources = {
    default = { "lsp", "path", "buffer" },
  },
  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
    },
  },
})

vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})
