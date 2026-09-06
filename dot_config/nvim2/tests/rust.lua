-- Full config with the installed Rust toolchain; all files are disposable.
-- NVIM_APPNAME=nvim2 nvim --headless -i NONE -n \
--   '+luafile ~/.config/nvim2/tests/rust.lua' '+qa!'
local tmp = vim.fn.tempname()
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
local ok, err = xpcall(function()
  local root = tmp .. "/app"
  local path = root .. "/src/main.rs"
  write(root .. "/Cargo.toml", { "[package]", 'name="rust-probe"', 'version="0.1.0"', 'edition="2024"' })
  write(path, { 'fn main(){let _n: i32="wrong";}' })
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  assert(
    vim.wait(30000, function()
      local clients = vim.lsp.get_clients({ bufnr = buf })
      return #clients == 1 and clients[1].name == "rust-analyzer" and clients[1].initialized
    end, 100),
    "Expected exactly one Rustaceanvim client"
  )
  local client = vim.lsp.get_clients({ bufnr = buf })[1]
  assert(client.config.root_dir == root, "Wrong Cargo root")
  assert(client.config.settings["rust-analyzer"].check.command == "clippy", "Clippy default missing")
  assert(client.capabilities.textDocument.completion.completionItem.snippetSupport, "Blink capabilities missing")
  assert(client.capabilities.experimental.hoverActions, "Rustaceanvim capabilities missing")
  assert(vim.fn.exists(":RustLsp") == 2, "Rust-specific commands missing")
  assert(
    vim.wait(30000, function()
      return #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) > 0
    end, 100),
    "No initial type error"
  )
  assert(
    vim.wait(30000, function()
      return vim.treesitter.highlighter.active[buf] ~= nil
    end, 100),
    "Rust highlighting didn't start"
  )
  vim.treesitter.get_parser(buf):parse()
  local highlights = vim.inspect_pos(buf, 0, 0, { treesitter = true }).treesitter
  assert(#highlights > 0, "Rust syntax has no Tree-sitter captures")
  print("Rust LSP: single client, initial diagnostics, Blink capabilities and Tree-sitter passed")

  -- Saving uses rustfmt defaults without a rustfmt.toml. Clippy runs afterwards.
  local original = 'fn main(){let x=vec![1,2];if x.len()==0{println!("empty");}}'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { original })
  vim.cmd.write()
  assert(vim.fn.readfile(path)[1] == "fn main() {", "Cargo project wasn't formatted on save")
  assert(
    vim.wait(30000, function()
      return vim.iter(vim.diagnostic.get(buf)):any(function(d)
        return tostring(d.code):find("len_zero", 1, true) ~= nil
      end)
    end, 100),
    "No Clippy lint after save"
  )
  print("Rust save: rustfmt defaults and Clippy diagnostics passed")

  -- :Format changes only the buffer, using config near the file even when the
  -- editor's current directory points elsewhere. Async syntax needs edition >=2018.
  write(root .. "/rustfmt.toml", { "hard_tabs = true" })
  local before = vim.fn.readfile(path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "async fn helper(){let _x=1;}", "fn main(){}" })
  vim.cmd.Format()
  assert(
    vim.wait(10000, function()
      return vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "\tlet _x = 1;"
    end, 50),
    "Manual formatting didn't respect Rust edition/config"
  )
  assert(vim.deep_equal(vim.fn.readfile(path), before), "Manual formatting saved the file")

  -- Standalone files format only on demand.
  local standalone = tmp .. "/standalone.rs"
  write(standalone, { "fn main(){let _x=1;}" })
  vim.cmd("edit! " .. vim.fn.fnameescape(standalone))
  vim.cmd.write()
  assert(vim.fn.readfile(standalone)[1] == "fn main(){let _x=1;}", "Standalone formatted on save")
  vim.cmd.Format()
  assert(
    vim.wait(10000, function()
      return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "fn main() {"
    end, 50),
    "Standalone manual formatting failed"
  )
  print("Rust manual formatting: file config, edition, no write and standalone fallback passed")
end, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.cmd("enew!")
vim.fn.delete(tmp, "rf")
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
print("Rust integration passed")
