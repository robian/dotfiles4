local typescript = require("config.typescript.project")
local M = { servers = { "vtsls", "eslint", "biome", "tailwindcss" } }
local filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

local function root_when(detect, project_root)
  return function(bufnr, on_dir)
    local ok, context = pcall(typescript.new, vim.api.nvim_buf_get_name(bufnr))
    local success, enabled = false, context
    if ok then
      success, enabled = pcall(detect, context)
    end
    if not ok or not success then
      vim.notify_once(tostring(enabled), vim.log.levels.WARN, { title = "TypeScript tooling" })
    elseif enabled then
      on_dir(project_root and project_root(context) or context.root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end
  end
end

function M.setup()
  local settings = {
    suggest = { completeFunctionCalls = true },
    inlayHints = {
      enumMemberValues = { enabled = true },
      functionLikeReturnTypes = { enabled = true },
      parameterNames = { enabled = "literals" },
      parameterTypes = { enabled = true },
      propertyDeclarationTypes = { enabled = true },
      variableTypes = { enabled = false },
    },
  }
  vim.lsp.config("vtsls", {
    root_dir = root_when(function(context)
      return not context.find({ "deno.json", "deno.jsonc", "deno.lock" })
    end),
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
        experimental = { maxInlayHintLength = 30, completion = { enableServerSideFuzzyMatch = true } },
      },
      typescript = settings,
      javascript = vim.deepcopy(settings),
    },
  })
  vim.lsp.config("eslint", {
    filetypes = filetypes,
    root_dir = root_when(function(context)
      return context.find({
        "eslint.config.js",
        "eslint.config.mjs",
        "eslint.config.cjs",
        "eslint.config.ts",
        "eslint.config.mts",
        "eslint.config.cts",
        ".eslintrc",
        ".eslintrc.js",
        ".eslintrc.cjs",
        ".eslintrc.json",
        ".eslintrc.yaml",
        ".eslintrc.yml",
      }) or context.package_field("eslintConfig") ~= nil
    end),
    settings = { format = false, workingDirectory = { mode = "auto" } },
  })
  vim.lsp.config("biome", {
    root_dir = root_when(function(context)
      return context.find({ "biome.json", "biome.jsonc" })
    end, function(context)
      -- Independent nested Biome roots can use different versions/configs.
      return vim.fs.dirname(context.find({ "biome.json", "biome.jsonc" }))
    end),
  })
  vim.lsp.config("tailwindcss", {
    filetypes = vim.list_extend(vim.deepcopy(filetypes), { "css", "scss", "html" }),
    root_dir = root_when(function(context)
      -- v3 has a config file. v4 typically only declares tailwindcss and uses
      -- @import "tailwindcss" in CSS; let the server discover those entrypoints.
      return context.dependency("tailwindcss")
        or context.find({
          "tailwind.config.js",
          "tailwind.config.cjs",
          "tailwind.config.mjs",
          "tailwind.config.ts",
        })
    end),
  })
  -- Prefer workspace binaries, including hoisted monorepo tools, then Mason.
  for name, command in pairs({
    vtsls = "vtsls",
    eslint = "vscode-eslint-language-server",
    biome = "biome",
    tailwindcss = "tailwindcss-language-server",
  }) do
    vim.lsp.config(name, {
      cmd = function(dispatchers, config)
        local context = typescript.new(vim.fs.joinpath(config.root_dir or vim.fn.getcwd(), "__lsp__"))
        return vim.lsp.rpc.start(
          { context.command(command), name == "biome" and "lsp-proxy" or "--stdio" },
          dispatchers
        )
      end,
    })
  end
end

return M
