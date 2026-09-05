-- Cpp filetype plugin --
-- See after/ftplugin/c.lua for why this no longer wraps in a BufEnter
-- autocmd on a shared, clearable augroup.
local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].expandtab = false -- Use tabs instead of spaces
vim.bo[bufnr].tabstop = 2 -- Width of a tab character
vim.bo[bufnr].shiftwidth = 2 -- Indentation width
vim.bo[bufnr].softtabstop = 2 -- Editing width of a tab
