return {
  name = "biome",
  package = "biome",
  detect = function(context)
    -- Biome itself resolves JSONC, extends, per-language/override enable flags
    -- and exclusions. Never force its formatter on with a CLI override.
    local config = context.find({ "biome.json", "biome.jsonc" })
    if not config then
      return false
    end
    local command = context.command("biome")
    if vim.fn.executable(command) ~= 1 then
      return true -- Preserve policy while Mason installs; Conform reports unavailable.
    end
    -- Empty stdin is a read-only probe of Biome's effective per-file policy.
    -- This handles inherited JSONC settings without a second config parser,
    -- and lets a lint-only Biome config coexist with Prettier automatically.
    local result = vim
      .system({ command, "format", "--stdin-file-path", context.filename }, {
        cwd = vim.fs.dirname(config),
        stdin = "",
        text = true,
      })
      :wait(1000)
    local stderr = result.stderr or ""
    if stderr:find("formatter is currently disabled", 1, true) or stderr:find("is ignored.", 1, true) then
      return false
    end
    if result.code ~= 0 then
      error("Biome policy check failed: " .. (stderr ~= "" and stderr or tostring(result.code)))
    end
    return true
  end,
}
