return {
  name = "prettier",
  package = "prettier",
  detect = function(context)
    -- Config presence declares policy; dependencies/installed binaries alone
    -- do not. Prettier evaluates JS/TS configs, shared packages and overrides.
    return context.find({
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.json5",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.toml",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      ".prettierrc.ts",
      ".prettierrc.cts",
      ".prettierrc.mts",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
      "prettier.config.ts",
      "prettier.config.cts",
      "prettier.config.mts",
    }) or context.package_field("prettier") ~= nil
  end,
}
