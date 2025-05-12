-- Lua filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("CMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local copts = function(desc)
      return { desc = desc, buffer = bufnr, noremap = true, silent = true }
    end
    vim.bo.expandtab = false -- Use tabs instead of spaces
    vim.bo.tabstop = 2 -- Width of a tab character
    vim.bo.shiftwidth = 2 -- Indentation width
    vim.bo.softtabstop = 2 -- Editing width of a tab
  end,
})
