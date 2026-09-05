-- Exercise cold startup with an existing error, using the full nvim2 config.
-- nvim --headless -u NONE -i NONE -l ~/.config/nvim2/tests/python_standalone.lua
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.fn.writefile({ "import datetime", "import os", "", "datetime.datetime()" }, tmp .. "/main.py")
vim.fn.writefile(
  vim.split(
    [[
local ok, err = xpcall(function()
  assert(vim.wait(10000, function()
    return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }) > 0
  end, 100), "No initial error diagnostic")
  -- Startup used to briefly report the error, then clear it. Don't pass just
  -- because a diagnostic arrived once: it must survive startup settling.
  vim.wait(2000, function() return false end, 100)
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  assert(#clients == 2, "Expected Pyright and Ruff")
  for _, name in ipairs({ "pyright", "ruff" }) do
    local client = vim.lsp.get_clients({ bufnr = 0, name = name })[1]
    assert(client and client.initialized, "Expected initialized " .. name)
    assert(client.config.root_dir == nil, "Standalone file acquired a project root")
  end
  local errors = vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
  assert(vim.iter(errors):any(function(d) return d.code == "reportCallIssue" end), "Initial error disappeared")
  assert(vim.iter(vim.diagnostic.get(0)):any(function(d)
    return d.source == "Ruff" and d.code == "F401"
  end), "Missing standalone Ruff diagnostic")
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
]],
    "\n"
  ),
  tmp .. "/check.lua"
)

local ok, err = xpcall(function()
  for _ = 1, 3 do
    local result = vim
      .system({
        vim.v.progpath,
        "--headless",
        "-i",
        "NONE",
        "-n",
        tmp .. "/main.py",
        "+luafile " .. tmp .. "/check.lua",
      }, { env = { NVIM_APPNAME = "nvim2" }, text = true })
      :wait(20000)
    assert(result.code == 0, result.stderr or "Standalone startup failed")
  end
end, debug.traceback)
vim.fn.delete(tmp, "rf")
assert(ok, err)
print("Python standalone startup: diagnostics persisted in 3 launches")
