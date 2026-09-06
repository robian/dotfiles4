vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, {
  desc = "Show diagnostic",
})

local function navigation_root()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    filename = vim.fs.joinpath(vim.fn.getcwd(), "__navigation__")
  end
  -- Use the edited file's nearest project marker or Git boundary. For a
  -- standalone file, browse its directory; an unnamed buffer starts at :pwd.
  return require("util.project").root(filename, {
    ".nvim.json",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "Cargo.toml",
    "package.json",
  }) or vim.fs.dirname(filename)
end

vim.keymap.set("n", "<leader>e", function()
  require("snacks").explorer({ cwd = navigation_root() })
end, { desc = "Explorer (project)" })

vim.keymap.set("n", "<leader><space>", function()
  require("snacks").picker.files({ cwd = navigation_root() })
end, { desc = "Find files (project)" })

vim.keymap.set("n", "<leader>/", function()
  require("snacks").picker.grep({ cwd = navigation_root() })
end, { desc = "Search text (project)" })

vim.keymap.set("n", "<leader>sR", function()
  require("snacks").picker.resume()
end, { desc = "Resume last picker" })
