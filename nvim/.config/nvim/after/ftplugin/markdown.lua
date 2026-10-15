-- markdown.lua
local bufnr = vim.api.nvim_get_current_buf()

vim.wo.wrap = true -- apply immediately to the window this buffer just opened in

vim.api.nvim_create_autocmd("BufWinEnter", {
  buffer = bufnr,
  callback = function()
    vim.wo.wrap = true
  end,
})
