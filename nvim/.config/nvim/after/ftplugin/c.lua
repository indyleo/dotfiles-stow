-- c.lua
local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].expandtab = false -- Use tabs instead of spaces
vim.bo[bufnr].tabstop = 2 -- Width of a tab character
vim.bo[bufnr].shiftwidth = 2 -- Indentation width
vim.bo[bufnr].softtabstop = 2 -- Editing width of a tab
