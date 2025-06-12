-- Rust filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("RustMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local rsopts = function(desc)
      return { desc = desc, buffer = bufnr, noremap = true, silent = true }
    end
    keymap("n", "<leader>a", function()
      vim.cmd.RustLsp "codeAction" -- supports rust-analyzer's grouping
      -- or vim.lsp.buf.codeAction() if you don't want grouping.
    end, rsopts "Code actions")
    keymap(
      "n",
      "K", -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
      function()
        vim.cmd.RustLsp { "hover", "actions" }
      end,
      rsopts "Hover actions"
    )
  end,
})
