-- Md filetype plugin --
-- See after/ftplugin/c.lua for the general BufEnter/shared-augroup issue.
-- `wrap` is genuinely window-local though, so it does need to be
-- (re)applied whenever *this buffer* is shown in a *new* window -- not on
-- every buffer focus, and not via a shared augroup name that a second
-- markdown buffer's `clear = true` would wipe out from under this one.
-- Scoping the autocmd to `buffer = bufnr` avoids that collision entirely.
local bufnr = vim.api.nvim_get_current_buf()

vim.wo.wrap = true -- apply immediately to the window this buffer just opened in

vim.api.nvim_create_autocmd("BufWinEnter", {
  buffer = bufnr,
  callback = function()
    vim.wo.wrap = true
  end,
})
