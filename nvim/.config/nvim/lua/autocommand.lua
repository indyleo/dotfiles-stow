-- autocommand.lua
-- NOTE: vim.loop is deprecated in Neovim 0.10+; use vim.uv instead.

local was_modified = {}

local function proc_check(program)
  local pids = vim.fn.systemlist { "sh", "-c", "pgrep -f " .. program }
  for _, pid in ipairs(pids) do
    pid = pid:match "^%s*(%d+)%s*$"
    if pid then
      local cmd = vim.fn.systemlist({ "sh", "-c", "ps -p " .. pid .. " -o args=" })[1] or ""
      if cmd:match(program) then return true end
    end
  end
  return false
end

local allowed_dirs = {
  vim.fn.expand "~/.config/nvim/lua/",
  vim.fn.expand "~/Github/dotfiles-stow/nvim/.config/nvim/lua/",
}

local function is_in_allowed_dir(filepath)
  for _, dir in ipairs(allowed_dirs) do
    if filepath:sub(1, #dir) == dir then return true end
  end
  return false
end

local function augroup(name)
  return vim.api.nvim_create_augroup(name, { clear = true })
end
local autocmd = vim.api.nvim_create_autocmd

-- Automatically add the header on new file creation
autocmd("BufNewFile", {
  group   = augroup "FileHeader",
  pattern = "*",
  callback = function()
    vim.defer_fn(function()
      vim.cmd.FileHeader()
      vim.cmd.startinsert()
    end, 5)
  end,
})

-- Highlight on yank
autocmd("TextYankPost", {
  group    = augroup "Highlight-Yank",
  callback = function() vim.hl.on_yank() end,
})

-- Trim trailing whitespace
autocmd({ "BufWritePre" }, {
  group   = augroup "TrimTrailingWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- Hide "[Process exited 0]" when closing a terminal
autocmd("TermClose", {
  group    = augroup "SilentKill",
  callback = function()
    vim.cmd "silent! bd!"
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local bufnr = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype ~= "terminal" then
            vim.wo[win].statusline = "%!v:lua.status_line()"
          end
        end
      end
      vim.cmd.redrawstatus()
    end)
  end,
})

autocmd("TermOpen", {
  group   = augroup "TermSettings",
  pattern = "*",
  callback = function()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
  end,
})

-- Track modified state before write
autocmd("BufWritePre", {
  group   = augroup "TrackModified",
  pattern = { "config.def.h", "keymaps.lua", "options.lua", "guioptions.lua", "autocommand.lua", "init.lua" },
  callback = function(args)
    was_modified[args.buf] = vim.bo.modified
  end,
})

-- Auto-compile config.def.h
autocmd("BufWritePost", {
  group   = augroup "AutoCompileConfig",
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
    was_modified[args.buf] = nil
  end,
})

-- Auto-reload Lua config files on save
autocmd("BufWritePost", {
  group   = augroup "AutoReload",
  pattern = { "keymaps.lua", "options.lua", "guioptions.lua", "autocommand.lua", "init.lua" },
  callback = function(args)
    local filepath = vim.fn.expand "%:p"
    if was_modified[args.buf] and is_in_allowed_dir(filepath) then
      vim.cmd.luafile(filepath)
      vim.notify("Reloaded " .. vim.fn.expand "%:t", vim.log.levels.INFO)
    end
    was_modified[args.buf] = nil
  end,
})
