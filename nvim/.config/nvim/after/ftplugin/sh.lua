-- sh.lua
local bufnr = vim.api.nvim_get_current_buf()
local langopts = function(desc)
  return { desc = "Shell: " .. desc, buffer = bufnr, noremap = true, silent = true }
end
-- Run format for function name(){}
vim.keymap.set(
  "n",
  "<leader>mu",
  [[:%s/^\s*\(\w\+\)\s*()/function \1()/<CR>]],
  langopts "formats the file to use function name(){} not name(){}"
)
