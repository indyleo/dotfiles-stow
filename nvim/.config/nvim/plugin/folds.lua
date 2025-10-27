-- ===========================================================================
-- Folding Utilities for Neovim
-- ===========================================================================

-- Helper: check if any folds are closed
local function any_folds_closed()
  for l = 1, vim.fn.line "$" do
    if vim.fn.foldclosed(l) ~= -1 then
      return true
    end
  end
  return false
end

-- ===========================================================================
-- 1️⃣ Toggle all folds safely
-- ===========================================================================
local function toggle_all_folds()
  -- Recalculate folds (important for Treesitter)
  vim.cmd "silent! normal! zx"

  local ok, closed = pcall(any_folds_closed)
  if not ok then
    return -- skip if fold functions fail
  end

  if closed then
    vim.cmd "silent! normal! zR" -- open all
  else
    vim.cmd "silent! normal! zM" -- close all
  end
end

-- ===========================================================================
-- 2️⃣ Toggle fold under cursor (safe)
-- ===========================================================================
local function toggle_fold_under_cursor()
  local line = vim.fn.line "."
  vim.cmd "silent! normal! zx" -- ensure folds updated

  local fold_start = vim.fn.foldclosed(line)
  local fold_end = vim.fn.foldclosedend(line)

  -- No fold at cursor → do nothing
  if fold_start == -1 and fold_end == -1 then
    return
  end

  if fold_start == -1 then
    vim.cmd "silent! normal! zc" -- open → close
  else
    vim.cmd "silent! normal! zo" -- close → open
  end
end

-- ===========================================================================
-- 3️⃣ Peek fold under cursor (scrollable floating window)
-- ===========================================================================
local peek_win = nil

local function peek_fold()
  local line = vim.fn.line "."
  local fold_start = vim.fn.foldclosed(line)

  -- Close peek if already open
  if peek_win and vim.api.nvim_win_is_valid(peek_win) then
    vim.api.nvim_win_close(peek_win, true)
    peek_win = nil
    return
  end

  -- No fold under cursor → show LSP hover instead
  if fold_start == -1 then
    vim.lsp.buf.hover()
    return
  end

  local fold_end = vim.fn.foldclosedend(line)
  local lines = vim.fn.getline(fold_start, fold_end)
  if not lines or #lines == 0 then
    return
  end

  -- Create temporary buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = vim.bo.filetype
  vim.bo[buf].modifiable = false

  -- Calculate window dimensions
  local max_width = 0
  for _, l in ipairs(lines) do
    max_width = math.max(max_width, #l)
  end

  local width = math.min(100, math.max(20, max_width))
  local height = math.min(25, #lines)

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

  peek_win = vim.api.nvim_open_win(buf, false, opts)

  -- Define a safe close function
  local function close_peek()
    if peek_win and vim.api.nvim_win_is_valid(peek_win) then
      vim.api.nvim_win_close(peek_win, true)
    end
    peek_win = nil
  end

  -- Local keymaps (use Lua callbacks, not strings)
  vim.keymap.set("n", "<Esc>", close_peek, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", close_peek, { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-d>", "<C-d>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-u>", "<C-u>", { buffer = buf, silent = true })

  -- Auto-close when leaving buffer/window
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = close_peek,
  })
end

-- ===========================================================================
-- 🧩 User Commands
-- ===========================================================================
vim.api.nvim_create_user_command("ToggleAllFolds", toggle_all_folds, {})
vim.api.nvim_create_user_command("ToggleFold", toggle_fold_under_cursor, {})
vim.api.nvim_create_user_command("PeekFold", peek_fold, {})
