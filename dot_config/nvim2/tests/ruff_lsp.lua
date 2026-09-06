-- NVIM_APPNAME=nvim2 nvim --headless -i NONE -n \
--   '+luafile /home/dev/.config/nvim2/tests/ruff_lsp.lua' '+qa!'
local tmp = vim.fn.tempname()
local ok, err = xpcall(function()
  for _, checker in ipairs({ "pyright", "basedpyright", "ty" }) do
    local root = tmp .. "/" .. checker
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({
      "[dependency-groups]",
      'dev=["' .. checker .. '"]',
      "[tool." .. checker .. "]",
      "[tool.ruff.lint]",
      'select = ["F401"]',
    }, root .. "/pyproject.toml")
    local lines = { "import os", 'answer:int= "wrong"' }
    local file = root .. "/main.py"
    vim.fn.writefile(lines, file)
    vim.cmd.edit(vim.fn.fnameescape(file))
    local buf = vim.api.nvim_get_current_buf()
    assert(
      vim.wait(20000, function()
        local clients = vim.lsp.get_clients({ bufnr = buf })
        return #clients == 2 and vim.iter(clients):all(function(c)
          return c.initialized
        end)
      end, 100),
      checker .. ": expected two initialized clients"
    )
    assert(vim.lsp.get_clients({ bufnr = buf, name = checker })[1])
    local ruff = assert(vim.lsp.get_clients({ bufnr = buf, name = "ruff" })[1])
    local lint
    assert(
      vim.wait(20000, function()
        local type_error = false
        for _, d in ipairs(vim.diagnostic.get(buf)) do
          if d.source == "Ruff" and d.code == "F401" then
            lint = d
          end
          if d.source ~= "Ruff" and d.lnum == 1 then
            type_error = true
          end
        end
        return lint ~= nil and type_error
      end, 100),
      checker .. ": missing lint or type diagnostic: " .. vim.inspect(vim.diagnostic.get(buf))
    )
    assert(ruff.server_capabilities.hoverProvider == false)
    assert(ruff.server_capabilities.documentFormattingProvider == false)
    local response = ruff:request_sync("textDocument/codeAction", {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 9 } },
      context = { diagnostics = { lint.user_data.lsp }, only = { "quickfix" } },
    }, 5000, buf)
    assert(response and not response.err and #response.result > 0, "No Ruff quickfix")
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines), "Linting mutated buffer")
    vim.cmd.write()
    assert(vim.deep_equal(vim.fn.readfile(file), lines), "Saving applied fixes or formatting without policy")
    print(checker .. " + Ruff: initial diagnostics, explicit quickfix, no save mutations")
  end
end, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.cmd.enew()
vim.fn.delete(tmp, "rf")
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
print("Ruff LSP integration passed")
