-- Automatically add the header on new file creation
vim.api.nvim_create_autocmd("BufNewFile", {
  group = vim.api.nvim_create_augroup("FileHeader", { clear = true }),
  pattern = "*",
  callback = function()
    -- Delay execution to ensure filetype is set
    vim.defer_fn(function()
      vim.cmd.FileHeader()
      vim.cmd.startinsert()
    end, 5) -- Delay of 5ms
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("Highlight-Yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Hides the "[Process exited 0]" call whenever you close a terminal
vim.api.nvim_create_autocmd("TermClose", {
  group = vim.api.nvim_create_augroup("SilentKill", { clear = true }),
  callback = function()
    vim.cmd "silent! bd!" -- Close the buffer silently
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("TermSettings", { clear = true }),
  pattern = "*",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

-- Auto command for config.def.h
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("AutoInstall", { clear = true }),
  pattern = "config.def.h",
  callback = function()
    local shellcmd = { "sudo cp config.def.h config.h && sudo make clean install" }
    vim.cmd.CommandRun(shellcmd)
  end,
})
