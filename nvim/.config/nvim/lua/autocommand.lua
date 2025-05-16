-- Vars/Functions
local was_modified = {}
local function proc_check(program)
  local pids = vim.fn.systemlist { "sh", "-c", "pgrep -f " .. program }

  for _, pid in ipairs(pids) do
    -- Trim PID and verify it's a number
    pid = pid:match "^%s*(%d+)%s*$"
    if pid then
      -- Get the actual command used to start the process
      local cmd = vim.fn.systemlist({ "sh", "-c", "ps -p " .. pid .. " -o args=" })[1] or ""
      if cmd:match(program) then
        return true
      end
    end
  end

  return false
end

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

-- Save the modified state *before* write
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("TrackModified", { clear = true }),
  pattern = { "config.def.h", "keymaps.lua", "options.lua", "guioptions.lua", "autocommand.lua", "init.lua" },
  callback = function(args)
    was_modified[args.buf] = vim.bo.modified
  end,
})

-- Auto command for config.def.h (only run if modified)
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("AutoInstall", { clear = true }),
  pattern = "config.def.h",
  callback = function(args)
    if not proc_check "autocompile" then
      local shellcmd = { "sudo cp config.def.h config.h && sudo make clean install" }
      if was_modified[args.buf] and vim.bo.filetype ~= "" and vim.fn.expand "%" ~= "" then
        vim.cmd.CommandRun(shellcmd)
      end
    else
      vim.notify("AutoCompilation already running", vim.log.levels.WARN)
    end
    was_modified[args.buf] = nil -- clear flag
  end,
})

-- Auto reload run lua files if changerd and a neovim config file (only run if modified)
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("AutoReload", { clear = true }),
  pattern = { "keymaps.lua", "options.lua", "guioptions.lua", "autocommand.lua", "init.lua" },
  callback = function(args)
    if was_modified[args.buf] and vim.bo.filetype ~= "" and vim.fn.expand "%" ~= "" then
      vim.cmd.luafile(vim.fn.expand "%")
      vim.notify("Reloaded " .. vim.fn.expand "%:t", vim.log.levels.INFO)
    end
    was_modified[args.buf] = nil -- clear flag
  end,
})
