-- Full config and real installed formatters; all writes are disposable files.
-- NVIM_APPNAME=nvim2 nvim --headless -i NONE -n \
--   '+luafile ~/.config/nvim2/tests/formatting_integration.lua' '+qa!'
local tmp = vim.fn.tempname()
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
local notifications = {}
local notify = vim.notify
vim.notify = function(message)
  notifications[#notifications + 1] = message
end

local ok, err = xpcall(function()
  assert(vim.fn.exists(":Format") == 2 and vim.fn.exists(":RuffFormat") == 0)
  local cases = {
    { name = "no-policy", files = {}, manual = true },
    {
      name = "dependencies",
      files = { ["pyproject.toml"] = { "[project]", 'dependencies=["ruff","black"]' } },
      manual = true,
    },
    { name = "lint-only", files = { ["ruff.toml"] = { "[lint]" } }, manual = true },
    {
      name = "ruff",
      files = { ["pyproject.toml"] = { "[tool.ruff.format]", 'quote-style="single"' } },
      expected = "x = {'a': 1}",
    },
    { name = "black", files = { ["pyproject.toml"] = { "[tool.black]" } }, expected = 'x = {"a": 1}' },
    {
      name = "override",
      files = { [".nvim.json"] = { '{"python":{"formatter":"black"}}' } },
      expected = 'x = {"a": 1}',
    },
    { name = "excluded", files = { ["ruff.toml"] = { 'exclude=["main.py"]', "[format]" } } },
    { name = "conflict", files = { ["pyproject.toml"] = { "[tool.black]", "[tool.ruff.format]" } }, blocked = true },
    { name = "disabled", files = { [".nvim.json"] = { '{"python":{"formatter":false}}' } }, blocked = true },
  }
  for _, case in ipairs(cases) do
    local root = tmp .. "/" .. case.name
    for name, lines in pairs(case.files) do
      write(root .. "/" .. name, lines)
    end
    local original = 'x=  {"a":1}'
    local path = root .. "/main.py"
    write(path, { original })
    write(root .. "/sibling.py", { original })
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.cmd.write()
    assert(vim.fn.readfile(path)[1] == (case.expected or original), case.name .. ": wrong save result")
    if case.manual then
      vim.cmd.Format()
      assert(
        vim.wait(10000, function()
          return vim.api.nvim_get_current_line() ~= original
        end, 50),
        case.name .. ": manual formatting failed"
      )
      assert(vim.fn.readfile(path)[1] == original, "Manual format saved the file")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { original })
      vim.cmd.write()
      assert(vim.fn.readfile(path)[1] == original, "Manual command enabled subsequent format-on-save")
    elseif case.blocked then
      local count = #notifications
      vim.cmd.Format()
      vim.wait(100, function()
        return false
      end)
      assert(vim.api.nvim_get_current_line() == original, "Blocked project was formatted")
      -- Conflict warnings may already have been emitted once during save.
      assert(#notifications > count or case.name == "conflict", "Missing disabled-policy explanation")
    end
    assert(vim.fn.readfile(root .. "/sibling.py")[1] == original, "Another file was formatted")
    print(case.name .. ": passed")
  end
  local path = tmp .. "/lua/main.lua"
  local original = "local x={1,2}"
  write(path, { original })
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.cmd.write()
  assert(vim.fn.readfile(path)[1] == original, "Lua formatted on save without policy")
  vim.cmd.Format()
  assert(
    vim.wait(10000, function()
      return vim.api.nvim_get_current_line() ~= original
    end, 50),
    "Lua manual fallback failed"
  )
  assert(vim.fn.readfile(path)[1] == original, "Manual Lua format saved the file")
  write(tmp .. "/lua/stylua.toml", { "indent_width=2" })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { original })
  vim.cmd.write()
  assert(vim.fn.readfile(path)[1] ~= original, "Lua project policy didn't enable format-on-save")

  vim.cmd("enew!")
  vim.bo.filetype = "python"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x=  [1,2]" })
  vim.cmd.Format()
  assert(
    vim.wait(10000, function()
      return vim.api.nvim_get_current_line() == "x = [1, 2]"
    end, 50),
    "Unnamed Python buffer didn't format"
  )
  vim.cmd("enew!")
  vim.bo.filetype = "typescript"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "let x=1" })
  local count = #notifications
  vim.cmd.Format()
  assert(#notifications == count + 1, "Unsupported language wasn't explained")
  assert(vim.api.nvim_get_current_line() == "let x=1", "Unsupported language was modified")
end, debug.traceback)
vim.notify = notify
vim.cmd("enew!")
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.fn.delete(tmp, "rf")
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
print("Project and manual formatting integration passed")
