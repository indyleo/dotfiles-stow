-- ========================
-- Folding Utilities for Neovim
-- Works with Treesitter and fallback methods
-- ========================

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

-- Refresh folds (important for Treesitter)
local function refresh_folds()
  cmd "silent! normal! zx"
end

-- Check if any folds are currently closed
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
  refresh_folds()
  if any_folds_closed() then
    cmd "normal! zR" -- open all
  else
    cmd "normal! zM" -- close all
  end
end

-- ========================
-- Toggle fold under cursor
-- ========================
local function toggle_fold_under_cursor()
  refresh_folds()
  local line = fn.line "."
  local fold_closed = fn.foldclosed(line)

  if fold_closed == -1 then
    cmd "silent! normal! zc" -- open → close
  else
    cmd "silent! normal! zo" -- closed → open
  end
end

-- ========================
-- Peek fold contents in floating window
-- ========================
local peek_win = nil

local function peek_fold()
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)

  -- If window already open, close it
  if peek_win and api.nvim_win_is_valid(peek_win) then
    api.nvim_win_close(peek_win, true)
    peek_win = nil
    return
  end

  -- No fold? show LSP hover instead
  if fold_start == -1 then
    vim.lsp.buf.hover()
    return
  end

  local fold_end = fn.foldclosedend(line)
  local lines = fn.getline(fold_start, fold_end)
  if not lines or #lines == 0 then
    return
  end

  -- Create floating buffer
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "filetype", vim.bo.filetype)
  api.nvim_buf_set_option(buf, "modifiable", false)

  -- Calculate dimensions
  local width = math.min(
    100,
    math.max(unpack(vim.tbl_map(function(s)
      return #s
    end, lines)))
  )
  local height = math.min(20, #lines)

  -- Floating window options
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

  -- Close function
  local function close_peek()
    if peek_win and api.nvim_win_is_valid(peek_win) then
      api.nvim_win_close(peek_win, true)
    end
    peek_win = nil
  end

  -- Close when leaving buffer/window
  api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = close_peek,
  })

  -- Local keymaps for navigation / closing
  local opts_key = { noremap = true, silent = true, nowait = true }
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", { callback = close_peek, noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, "n", "q", "", { callback = close_peek, noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, "n", "<C-d>", "<C-d>", opts_key)
  api.nvim_buf_set_keymap(buf, "n", "<C-u>", "<C-u>", opts_key)
end

-- ========================
-- User commands
-- ========================
api.nvim_create_user_command("ToggleAllFolds", toggle_all_folds, {})
api.nvim_create_user_command("ToggleFold", toggle_fold_under_cursor, {})
api.nvim_create_user_command("PeekFold", peek_fold, {})
