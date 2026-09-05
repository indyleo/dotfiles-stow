-- C filetype plugin --
-- NOTE: files under after/ftplugin/ already run exactly once per buffer,
-- right when 'filetype' is set to this value -- wrapping the body in a
-- BufEnter autocmd on a shared, `clear = true` augroup was unnecessary and
-- actively harmful: opening a *second* C buffer would wipe the "CMaps"
-- augroup, silently dropping the first buffer's autocmd, and every time you
-- refocused a C buffer these options would be forced back on, clobbering
-- any per-buffer override you made by hand (e.g. `:setlocal et`). Just set
-- the buffer-local options directly.
local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].expandtab = false -- Use tabs instead of spaces
vim.bo[bufnr].tabstop = 2 -- Width of a tab character
vim.bo[bufnr].shiftwidth = 2 -- Indentation width
vim.bo[bufnr].softtabstop = 2 -- Editing width of a tab
