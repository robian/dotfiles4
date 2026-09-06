-- Languages own project policy and manual defaults; this file only dispatches.
local languages = {
  lua = require("config.formatting.lua"),
  python = require("config.formatting.python"),
  rust = require("config.formatting.rust"),
}
local web = require("config.formatting.web")
for _, ft in ipairs({
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "css",
  "scss",
  "json",
  "jsonc",
  "html",
}) do
  languages[ft] = web
end
local conform = require("conform")
local registry = require("mason-registry")
local tools, formatters, formatters_by_ft = {}, {}, {}

local function select(bufnr, manual)
  local language = languages[vim.bo[bufnr].filetype]
  if not language then
    return nil
  end
  local ok, choice = pcall(language.select, vim.api.nvim_buf_get_name(bufnr), manual)
  if not ok then
    local notify = manual and vim.notify or vim.notify_once
    notify(tostring(choice), vim.log.levels.WARN, { title = "Formatting" })
    return nil, true
  end
  return choice
end

for ft, language in pairs(languages) do
  for _, tool in ipairs(language.tools) do
    if not vim.tbl_contains(tools, tool.package) then
      tools[#tools + 1] = tool.package
    end
  end
  formatters = vim.tbl_extend("force", formatters, language.formatters or {})
  formatters_by_ft[ft] = function(bufnr)
    local choice = select(bufnr, false)
    return choice and choice.formatter and { choice.formatter } or {}
  end
end

registry.refresh(function()
  for _, name in ipairs(tools) do
    local package = registry.get_package(name)
    if not package:is_installed() and not package:is_installing() then
      package:install()
    end
  end
end)

conform.setup({
  formatters_by_ft = formatters_by_ft,
  formatters = formatters,
  -- No policy means no save hook action, including no LSP fallback.
  format_on_save = function(bufnr)
    local choice = select(bufnr, false)
    if choice and choice.formatter then
      return { formatters = { choice.formatter }, timeout_ms = 1000, lsp_format = "never" }
    end
  end,
})

-- Explicit invocation permits a language's manual fallback, but doesn't
-- change future saves, save the buffer, or format any other files.
pcall(vim.api.nvim_del_user_command, "RuffFormat")
vim.api.nvim_create_user_command("Format", function()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modifiable then
    vim.notify("Format requires an editable file buffer", vim.log.levels.WARN)
    return
  end
  local choice, failed = select(bufnr, true)
  if failed then
    return
  end
  if not choice or not choice.formatter then
    vim.notify(
      choice and choice.reason or "No formatter configured for filetype: " .. vim.bo[bufnr].filetype,
      vim.log.levels.WARN
    )
    return
  end
  conform.format({
    bufnr = bufnr,
    formatters = { choice.formatter },
    lsp_format = "never",
    async = true,
  })
end, { desc = "Format the current buffer using project policy or a manual default" })
