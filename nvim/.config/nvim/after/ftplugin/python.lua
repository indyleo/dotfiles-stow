-- Python filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("PythonMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local pyopts = function(desc)
      return { desc = "Python: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end
    -- Use spaces for indentation (Python standard)
    vim.bo.expandtab = true
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})
