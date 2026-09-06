-- Integration test using installed servers and the full nvim2 configuration.
-- NVIM_APPNAME=nvim2 nvim --headless -i NONE -n \
--   '+luafile /home/dev/.config/nvim2/tests/python_lsp.lua' '+qa!'
-- Creates disposable projects/venvs; requires python3 with the venv module.
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local cases = {
  { name = "pyright", config = '[dependency-groups]\ndev=["pyright"]\n[tool.pyright]\ntypeCheckingMode="basic"' },
  { name = "basedpyright", config = '[tool.basedpyright]\ntypeCheckingMode="basic"' },
  { name = "ty", config = "[tool.ty]" },
}
local ok, err = xpcall(function()
  for _, case in ipairs(cases) do
    local root = tmp .. "/" .. case.name
    vim.fn.mkdir(root, "p")
    vim.fn.writefile(vim.split(case.config, "\n"), root .. "/pyproject.toml")
    local env = root .. "/.venv"
    assert(vim.system({ "python3", "-m", "venv", "--without-pip", env }):wait().code == 0)
    local executable = env .. "/bin/python"
    local site = vim.trim(
      vim
        .system({ executable, "-c", 'import sysconfig; print(sysconfig.get_path("purelib"))' }, { text = true })
        :wait().stdout
    )
    vim.fn.writefile({ "VALUE: int = 1" }, site .. "/only_here.py")
    vim.fn.writefile({ "import only_here", "good: int = only_here.VALUE", 'answer: int = "wrong"' }, root .. "/main.py")
    vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
    local buf = vim.api.nvim_get_current_buf()
    assert(
      vim.wait(30000, function()
        local clients = vim.lsp.get_clients({ bufnr = buf })
        return #clients == 1 and clients[1].name == case.name and clients[1].initialized
      end, 100),
      case.name .. ": expected exactly one initialized LSP"
    )
    assert(
      vim.wait(30000, function()
        return #vim.diagnostic.get(buf) > 0
      end, 100),
      case.name .. ": no diagnostic for type error"
    )
    local client = vim.lsp.get_clients({ bufnr = buf })[1]
    local configured = case.name == "ty" and client.config.settings.ty.configuration.environment.python
      or client.config.settings.python.pythonPath
    assert(configured == executable, case.name .. ": wrong interpreter")
    for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
      assert(
        not diagnostic.message:find("only_here", 1, true),
        case.name .. ": project-only import did not resolve: " .. diagnostic.message
      )
    end
    print(case.name .. ": initialized, type error found, project .venv import resolved")
  end
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    if vim.tbl_contains({ "pyright", "basedpyright", "ty" }, client.name) then
      names[#names + 1] = client.name
      client:stop(true)
    end
  end
  assert(#names == 3, "Expected three different projects to run different servers simultaneously")
end, debug.traceback)
vim.cmd.enew()
vim.fn.delete(tmp, "rf")
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
print("Python multi-project LSP integration passed")
