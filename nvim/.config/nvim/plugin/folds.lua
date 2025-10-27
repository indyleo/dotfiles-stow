-- ========================
-- Folding Utilities for Neovim
-- Works with Treesitter and fallback methods
-- ========================

local api, fn, cmd = vim.api, vim.fn, vim.cmd

-- ========================
-- Refresh folds (important for Treesitter)
-- ========================
local function refresh_folds()
  cmd "silent! normal! zx"
end

-- ========================
-- Check if any folds are closed
-- ========================
local function any_folds_closed()
  for l = 1, fn.line "$" do
    if fn.foldclosed(l) ~= -1 then
      return true
    end
  end
  return false
end

-- ========================
-- Toggle all folds
-- ========================
local function toggle_all_folds()
  local cursor = api.nvim_win_get_cursor(0)
  refresh_folds()
  if any_folds_closed() then
    cmd "normal! zR" -- open all
  else
    cmd "normal! zM" -- close all
  end
  api.nvim_win_set_cursor(0, cursor)
end

-- ========================
-- Peek fold contents in floating window
-- ========================
local peek_win

local function close_peek()
  if peek_win and api.nvim_win_is_valid(peek_win) then
    api.nvim_win_close(peek_win, true)
  end
  peek_win = nil
end

local function peek_fold()
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)

  -- Close existing peek
  if peek_win and api.nvim_win_is_valid(peek_win) then
    close_peek()
    return
  end

  -- No fold? → LSP hover fallback
  if fold_start == -1 then
    if vim.lsp.buf.server_ready() then
      vim.lsp.buf.hover()
    else
      vim.notify("No fold or LSP hover available", vim.log.levels.INFO)
    end
    return
  end

  local fold_end = fn.foldclosedend(line)
  local lines = fn.getline(fold_start, fold_end)
  if not lines or #lines == 0 then
    return
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_set_option_value("filetype", vim.bo.filetype, { buf = buf })
  api.nvim_set_option_value("modifiable", false, { buf = buf })

  local screen_w = api.nvim_get_option_value("columns", {})
  local screen_h = api.nvim_get_option_value("lines", {})
  local width = math.min(math.floor(screen_w * 0.6), math.max(30, vim.fn.strdisplaywidth(lines[1] or "")))
  local height = math.min(math.floor(screen_h * 0.4), #lines)

  local opts = {
    relative = "cursor",
    width = width,
    height = height,
    col = 0,
    row = 1,
    style = "minimal",
    border = "rounded",
    noautocmd = true,
  }

  peek_win = api.nvim_open_win(buf, false, opts)

  -- Close on leave
  api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    once = true,
    callback = close_peek,
    desc = "Auto-close fold preview",
  })

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", close_peek, map_opts)
  vim.keymap.set("n", "<Esc>", close_peek, map_opts)
  vim.keymap.set("n", "<C-d>", "<C-d>", map_opts)
  vim.keymap.set("n", "<C-u>", "<C-u>", map_opts)
end

-- ========================
-- Toggle fold under cursor
-- ========================
local function toggle_fold_under_cursor()
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)

  -- Closed fold → open
  if fold_start ~= -1 then
    cmd "silent! normal! zo"
    return
  end

  -- Inside an open fold → find header and close
  local fold_level = fn.foldlevel(line)
  if fold_level > 0 then
    local search_line = line
    while search_line > 1 and fn.foldlevel(search_line - 1) >= fold_level do
      search_line = search_line - 1
    end
    api.nvim_win_set_cursor(0, { search_line, 0 })
    cmd "silent! normal! zc"
    return
  end

  vim.notify("No fold under cursor", vim.log.levels.INFO)
end

-- ========================
-- User Commands
-- ========================
api.nvim_create_user_command("ToggleAllFolds", toggle_all_folds, { desc = "Toggle all folds open/closed" })
api.nvim_create_user_command("ToggleFold", toggle_fold_under_cursor, { desc = "Toggle fold under cursor (with peek)" })
api.nvim_create_user_command("PeekFold", peek_fold, { desc = "Preview fold contents in floating window" })
