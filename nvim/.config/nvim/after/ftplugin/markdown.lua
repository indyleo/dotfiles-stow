-- Md filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("MDMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local winid = vim.api.nvim_get_current_win()

    local mdopts = function(desc)
      return { desc = "Markdown: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end

    -- Set word wrap (window-local!)
    vim.wo[winid].wrap = true
  end,
})
