-- Lua filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("LuaMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local langopts = function(desc)
      return { desc = "Lua: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end
    -- Run current line
    keymap("n", "<leader>rc", ":.lua<CR>", langopts "Runs line under cursor")
    -- Run current selection
    keymap("v", "<leader>rc", ":lua<CR>", langopts "Runs selection")
    -- Run current file
    keymap("n", "<leader>rf", ":luafile %<CR>", langopts "Runs current file")
  end,
})
