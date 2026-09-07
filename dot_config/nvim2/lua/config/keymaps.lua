local project = require("util.project")

vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, {
  desc = "Show diagnostic",
})

vim.keymap.set("n", "<leader>e", function()
  require("snacks").explorer({ cwd = project.navigation_root() })
end, { desc = "Explorer (project)" })

vim.keymap.set("n", "<leader><space>", function()
  require("snacks").picker.files({ cwd = project.navigation_root() })
end, { desc = "Find files (project)" })

vim.keymap.set("n", "<leader>,", function()
  require("snacks").picker.buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>/", function()
  require("snacks").picker.grep({ cwd = project.navigation_root() })
end, { desc = "Search text (project)" })

vim.keymap.set("n", "<leader>sR", function()
  require("snacks").picker.resume()
end, { desc = "Resume last picker" })
