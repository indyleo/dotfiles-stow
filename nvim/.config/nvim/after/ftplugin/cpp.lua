-- Cpp filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("CppMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local cppopts = function(desc)
      return { desc = "C++: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end
    vim.bo[bufnr].expandtab = false -- Use tabs instead of spaces
    vim.bo[bufnr].tabstop = 2 -- Width of a tab character
    vim.bo[bufnr].shiftwidth = 2 -- Indentation width
    vim.bo[bufnr].softtabstop = 2 -- Editing width of a tab
  end,
})
