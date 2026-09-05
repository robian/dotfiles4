-- Parser revisions and queries must follow the locked plugin revision.
-- Register before pack.add so restoring/updating from a lockfile is covered.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("nvim2_treesitter_updates", { clear = true }),
  callback = function(ev)
    if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
      vim.schedule(function()
        if not ev.data.active then
          vim.cmd.packadd("nvim-treesitter")
        end
        require("nvim-treesitter").update(nil, { summary = true })
      end)
    end
  end,
})

vim.pack.add({
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  { src = "https://github.com/mason-org/mason.nvim" },
  { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
  { src = "https://github.com/stevearc/conform.nvim" },
  {
    src = "https://github.com/saghen/blink.cmp",
    version = vim.version.range("1"),
  },
})
