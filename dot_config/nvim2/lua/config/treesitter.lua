local treesitter = require("nvim-treesitter")
-- NVIM_APPNAME keeps these parsers/queries separate from the old config.
treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })

local function highlight(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "python" then
    -- On first startup the parser may still be installing; retry below.
    pcall(vim.treesitter.start, bufnr)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvim2_treesitter", { clear = true }),
  pattern = "python",
  callback = function(ev)
    highlight(ev.buf)
  end,
})

-- Install missing parsers, without updating them on every startup. Lua already
-- has a parser, queries and highlighting enabled by Neovim's own ftplugin.
treesitter.install({ "python" }):await(vim.schedule_wrap(function(err, success)
  if err or success == false then
    vim.notify("Python Tree-sitter installation failed; see :TSLog", vim.log.levels.ERROR)
    return
  end
  -- Also highlight files opened while the asynchronous installation ran.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    highlight(bufnr)
  end
end))
