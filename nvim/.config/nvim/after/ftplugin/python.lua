-- Python filetype plugin --
-- See after/ftplugin/c.lua for why this no longer wraps in a BufEnter
-- autocmd on a shared, clearable augroup.
local bufnr = vim.api.nvim_get_current_buf()
-- Use spaces for indentation (Python standard)
vim.bo[bufnr].expandtab = true
vim.bo[bufnr].tabstop = 4
vim.bo[bufnr].shiftwidth = 4
vim.bo[bufnr].softtabstop = 4
