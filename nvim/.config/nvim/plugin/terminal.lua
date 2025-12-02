-- plugin/fileutils_terminal.lua
-- Terminal utilities as a standalone plugin file

------------------------------------------------------------
-- State
------------------------------------------------------------
local termstate = { floating = { buf = -1, win = -1 } }
local gitstate = { floating = { buf = -1, win = -1 } }
local cmdstate = { floating = { buf = -1, win = -1 } }
local foreverstate = { floating = { buf = -1, win = -1 } }

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function is_git_repo()
  local output = vim.fn.systemlist { "sh", "-c", "git rev-parse --is-inside-work-tree" }
  return vim.v.shell_error == 0 and output[1] == "true"
end

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf
  if vim.api.nvim_buf_is_valid(opts.buf) then
    buf = opts.buf
  else
    buf = vim.api.nvim_create_buf(false, true)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
  })

  return { buf = buf, win = win }
end

------------------------------------------------------------
-- Terminal: Toggle general terminal
------------------------------------------------------------
local function toggle_terminal()
  if not vim.api.nvim_win_is_valid(termstate.floating.win) then
    termstate.floating = create_floating_window { buf = termstate.floating.buf }
    if vim.bo[termstate.floating.buf].buftype ~= "terminal" then
      vim.cmd "terminal"
    end
    vim.cmd "startinsert"
  else
    vim.api.nvim_win_hide(termstate.floating.win)
  end
end

------------------------------------------------------------
-- Terminal: Git terminal
------------------------------------------------------------
local function toggle_git()
  if not is_git_repo() then
    vim.notify("Not in a git repo", vim.log.levels.WARN)
    return
  end

  if not vim.api.nvim_win_is_valid(gitstate.floating.win) then
    gitstate.floating = create_floating_window { buf = gitstate.floating.buf }
    if vim.bo[gitstate.floating.buf].buftype ~= "terminal" then
      vim.fn.termopen { "sh", "-c", "lazygit" }
    end
    vim.cmd "startinsert"

    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(gitstate.floating.win) then
        vim.api.nvim_set_current_win(gitstate.floating.win)
        vim.cmd "startinsert"
      end
    end, 50)
  else
    vim.api.nvim_win_hide(gitstate.floating.win)
  end
end

------------------------------------------------------------
-- Terminal: Run command once
------------------------------------------------------------
local function command_run(cmd)
  if not vim.api.nvim_win_is_valid(cmdstate.floating.win) then
    cmdstate.floating = create_floating_window { buf = cmdstate.floating.buf }
    if vim.bo[cmdstate.floating.buf].buftype ~= "terminal" then
      vim.fn.termopen { "sh", "-c", cmd }
    end
    vim.cmd "startinsert"
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(cmdstate.floating.win) then
        vim.api.nvim_set_current_win(cmdstate.floating.win)
        vim.cmd "startinsert"
      end
    end, 50)
  end
end

------------------------------------------------------------
-- Terminal: Run command forever (toggle)
------------------------------------------------------------
local function command_run_forever(cmd)
  if not vim.api.nvim_win_is_valid(foreverstate.floating.win) then
    foreverstate.floating = create_floating_window { buf = foreverstate.floating.buf }
    if vim.bo[foreverstate.floating.buf].buftype ~= "terminal" then
      vim.fn.termopen { "sh", "-c", cmd }
    end
    vim.cmd "startinsert"
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(foreverstate.floating.win) then
        vim.api.nvim_set_current_win(foreverstate.floating.win)
        vim.cmd "startinsert"
      end
    end, 50)
  else
    vim.api.nvim_win_hide(foreverstate.floating.win)
  end
end

------------------------------------------------------------
-- User Commands
------------------------------------------------------------
local mkcmd = vim.api.nvim_create_user_command

mkcmd("ToggleTerminal", toggle_terminal, {
  nargs = 0,
  desc = "Toggle general floating terminal",
})

mkcmd("ToggleGit", toggle_git, {
  nargs = 0,
  desc = "Toggle git fzf terminal",
})

mkcmd("CommandRun", function(args)
  command_run(args.args)
end, {
  nargs = "+",
  complete = "shellcmd",
  desc = "Run a shell command in a floating terminal",
})

mkcmd("CommandRunForever", function(args)
  command_run_forever(args.args)
end, {
  nargs = "+",
  complete = "shellcmd",
  desc = "Run a command repeatedly in a floating terminal",
})
