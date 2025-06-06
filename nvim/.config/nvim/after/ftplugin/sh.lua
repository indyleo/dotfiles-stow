-- Shell filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("ShellMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local langopts = function(desc)
      return { desc = desc, buffer = bufnr, noremap = true, silent = true }
    end
    -- Run format for function name(){}
    keymap("n", "<leader>mu", [[:%s/^\s*\(\w\+\)\s*()/function \1()/<CR>]], langopts "formats the file to use function name(){} not name(){}")
  end,
})
