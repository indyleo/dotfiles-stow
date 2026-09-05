-- Lua filetype plugin --
-- See after/ftplugin/c.lua for why this no longer wraps in a BufEnter
-- autocmd on a shared, clearable augroup.
local bufnr = vim.api.nvim_get_current_buf()
local langopts = function(desc)
  return { desc = "Lua: " .. desc, buffer = bufnr, noremap = true, silent = true }
end
-- Run current line
vim.keymap.set("n", "<leader>rc", ":.lua<CR>", langopts "Runs line under cursor")
-- Run current selection
vim.keymap.set("v", "<leader>rc", ":lua<CR>", langopts "Runs selection")
-- Run current file
vim.keymap.set("n", "<leader>rf", ":luafile %<CR>", langopts "Runs current file")
