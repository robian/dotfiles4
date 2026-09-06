require("snacks").setup({
  explorer = { enabled = true },
  picker = {
    enabled = true,
    ui_select = true, -- Use the picker for selection dialogs (e.g. LSP code actions).
  },
})
