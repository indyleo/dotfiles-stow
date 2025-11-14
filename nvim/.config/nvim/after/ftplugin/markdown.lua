-- Md filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("MDMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local mdopts = function(desc)
      return { desc = "Markdown: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end

    -- Markdown Code Extration
    keymap("n", "<leader>em", ":MarkdownCode<CR>", mdopts "Markdown Code Block Extration")

    -- Set word wrap
    vim.bo[bufnr].wrap = true
  end,
})
