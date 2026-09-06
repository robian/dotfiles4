local project = require("util.project")
local web = require("config.web.project")
local M = {
  tools = { require("config.formatting.web.prettier"), require("config.formatting.web.biome") },
}

-- Configs declare policy; neither a dependency nor ESLint lint rules imply
-- formatting. Two applicable formatters are ambiguous:
-- resolve with .nvim.json {"web":{"formatter":"prettier"|"biome"|false}}.
-- This also expresses policy held in external scripts/configuration. With no
-- policy, saves do nothing and :Format explicitly falls back to Prettier.
function M.select(filename, manual)
  local context = web.new(filename)
  local override_path = context.find({ ".nvim.json" })
  local override = override_path and project.get(project.read(override_path), "web") or {}
  if type(override) ~= "table" then
    error(".nvim.json web must be an object")
  end
  if override.formatter == false then
    return { disabled = true, reason = "Web formatting is disabled in .nvim.json" }
  end
  local matches = {}
  for _, tool in ipairs(M.tools) do
    if override.formatter == tool.name or (override.formatter == nil and tool.detect(context)) then
      matches[#matches + 1] = tool.name
    end
  end
  if override.formatter ~= nil and #matches == 0 then
    error("web.formatter must be prettier, biome or false")
  end
  if #matches > 1 then
    error("Both Prettier and Biome configs found; select web.formatter in .nvim.json")
  end
  if #matches == 0 and context.find({ "biome.json", "biome.jsonc" }) then
    return { disabled = true, reason = "Biome formatting is disabled or this file is excluded" }
  end
  if matches[1] or manual then
    return { formatter = matches[1] or "prettier", root = context.root, policy = matches[1] ~= nil }
  end
end

M.formatters = {}
for _, tool in ipairs(M.tools) do
  M.formatters[tool.name] = {
    command = function(_, ctx)
      return web.new(ctx.filename).command(tool.name)
    end,
    cwd = function(_, ctx)
      return web.new(ctx.filename).root or ctx.dirname
    end,
  }
end
-- Pass the actual filename so each tool applies file-specific settings and
-- exclusions. Use format, never biome check --write (lint/import fixes).
M.formatters.biome.args = { "format", "--stdin-file-path", "$FILENAME" }
M.formatters.biome.cwd = function(_, ctx)
  local config = web.new(ctx.filename).find({ "biome.json", "biome.jsonc" })
  return config and vim.fs.dirname(config) or ctx.dirname
end
M.formatters.prettier.prepend_args = function(_, ctx)
  local context = web.new(ctx.filename)
  local args = {}
  for _, name in ipairs({ ".gitignore", ".prettierignore" }) do
    local path = context.find({ name })
    if path then
      vim.list_extend(args, { "--ignore-path", path })
    end
  end
  return args
end

return M
