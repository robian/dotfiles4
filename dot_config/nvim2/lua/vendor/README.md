# Vendored dependencies

## tinytoml

- Upstream: https://github.com/FourierTransformer/tinytoml
- Release: `1.0.0`
- Commit: `663e319179c7800b414afbe58fe29bbe5cba3dec`
- Files: upstream `tinytoml.lua` and `LICENSE` (stored as `tinytoml.LICENSE`).
- License: MIT; see `tinytoml.LICENSE`.
- Local modifications: none. Keep the Lua file byte-for-byte upstream, including formatting.

Used by `lua/util/project.lua` to parse project TOML without an external
interpreter or a build step. Load with `require("vendor.tinytoml")`.

To update, replace both files from a specific upstream commit and update this
record. Run the Python project-selection and LSP tests in `tests/` afterward.
