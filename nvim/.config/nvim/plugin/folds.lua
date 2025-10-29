-- folds.lua
-- Robust folding utilities for Neovim with Treesitter support and fold preview.
-- Safely applies buffer-local fold settings and avoids invalid window-id errors.

if vim.g.loaded_folds_plugin then
  return
end
vim.g.loaded_folds_plugin = true

local api, fn, cmd = vim.api, vim.fn, vim.cmd
local M = {}

-- ========================
-- Default config + setup
-- ========================
M.config = {
  excluded_filetypes = { "help", "terminal", "dashboard", "NvimTree", "lazy" },
  max_file_lines = 20000, -- skip heavy scanning on very large files
}

--- Setup function to override defaults
-- @param opts table
function M.setup(opts)
  if opts == nil then
    opts = {}
  end
  for k, v in pairs(opts) do
    M.config[k] = v
  end
end

-- ========================
-- Helpers
-- ========================
local function is_excluded(ft)
  if not ft or ft == "" then
    return false
  end
  for _, v in ipairs(M.config.excluded_filetypes) do
    if v == ft then
      return true
    end
  end
  return false
end

local function has_ts_parser(ft)
  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  return ok and parsers and parsers.has_parser and parsers.has_parser(ft)
end

local function refresh_folds(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  local line_count = api.nvim_buf_line_count(bufnr)
  if line_count > M.config.max_file_lines then
    return
  end
  -- safe: run in the window displaying the buffer if present
  local ok, win = pcall(api.nvim_buf_get_var, bufnr, "_folds_dummy")
  -- simplest approach: use normal command on current window
  pcall(cmd, "silent! normal! zx")
end

-- ========================
-- Apply folding safely for a buffer
-- ========================
local function ensure_folding_for_filetype(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  if is_excluded(ft) then
    pcall(vim.api.nvim_set_option_value, "foldenable", false, { buf = bufnr })
    return
  end

  local opts = { buf = bufnr }

  if has_ts_parser(ft) then
    pcall(vim.api.nvim_set_option_value, "foldmethod", "expr", opts)
    pcall(vim.api.nvim_set_option_value, "foldexpr", "nvim_treesitter#foldexpr()", opts)
  else
    -- sensible fallbacks by filetype
    if ft == "python" or ft == "yaml" then
      pcall(vim.api.nvim_set_option_value, "foldmethod", "indent", opts)
    else
      -- syntax is often reasonable for C/C++/Rust when treesitter isn't available
      pcall(vim.api.nvim_set_option_value, "foldmethod", "syntax", opts)
    end
    pcall(vim.api.nvim_set_option_value, "foldexpr", "", opts)
  end

  pcall(vim.api.nvim_set_option_value, "foldenable", true, opts)
  pcall(vim.api.nvim_set_option_value, "foldlevel", 99, opts)
end

-- ========================
-- Fold inspection
-- ========================
local function any_folds_closed(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local last = api.nvim_buf_line_count(bufnr)
  if last > M.config.max_file_lines then
    return false
  end
  for l = 1, last do
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
  local bufnr = api.nvim_get_current_buf()
  ensure_folding_for_filetype(bufnr)
  refresh_folds(bufnr)

  local cursor = api.nvim_win_get_cursor(0)
  if any_folds_closed(bufnr) then
    pcall(cmd, "silent! normal! zR")
  else
    pcall(cmd, "silent! normal! zM")
  end
  api.nvim_win_set_cursor(0, cursor)
end

-- ========================
-- Peek fold contents (preview)
-- ========================
local peek_win

local function close_peek()
  if peek_win and api.nvim_win_is_valid(peek_win) then
    pcall(api.nvim_win_close, peek_win, true)
  end
  peek_win = nil
end

local function peek_fold()
  local bufnr = api.nvim_get_current_buf()
  ensure_folding_for_filetype(bufnr)

  local line = fn.line "."
  local fold_start = fn.foldclosed(line)

  if peek_win and api.nvim_win_is_valid(peek_win) then
    close_peek()
    return
  end

  if fold_start == -1 then
    pcall(vim.lsp.buf.hover)
    return
  end

  local fold_end = fn.foldclosedend(line)
  local lines = fn.getline(fold_start, fold_end)
  if not lines or #lines == 0 then
    return
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  pcall(api.nvim_set_option_value, "filetype", api.nvim_buf_get_option(bufnr, "filetype"), { buf = buf })
  pcall(api.nvim_set_option_value, "modifiable", false, { buf = buf })

  local screen_w = api.nvim_get_option_value("columns", {})
  local screen_h = api.nvim_get_option_value("lines", {})
  local width = math.floor(screen_w * 0.6)
  local height = math.min(#lines, math.floor(screen_h * 0.5))

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
  pcall(api.nvim_set_option_value, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = peek_win })

  api.nvim_create_autocmd({ "BufLeave", "WinScrolled", "InsertEnter", "WinLeave" }, {
    once = true,
    callback = close_peek,
    desc = "Auto-close fold preview",
  })

  local map_opts = { buffer = buf, silent = true, nowait = true }
  pcall(vim.keymap.set, "n", "q", close_peek, map_opts)
  pcall(vim.keymap.set, "n", "<Esc>", close_peek, map_opts)
end

-- ========================
-- Toggle fold under cursor
-- ========================
local function toggle_fold_under_cursor()
  local bufnr = api.nvim_get_current_buf()
  ensure_folding_for_filetype(bufnr)
  local orig_cursor = api.nvim_win_get_cursor(0)
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)

  if fold_start ~= -1 then
    api.nvim_win_set_cursor(0, { fold_start, 0 })
    pcall(cmd, "silent! normal! zo")
    api.nvim_win_set_cursor(0, orig_cursor)
    return
  end

  local fold_level = fn.foldlevel(line)
  if fold_level > 0 then
    local search_line = line
    while search_line > 1 and fn.foldlevel(search_line - 1) >= fold_level do
      search_line = search_line - 1
    end
    api.nvim_win_set_cursor(0, { search_line, 0 })
    pcall(cmd, "silent! normal! zc")
    api.nvim_win_set_cursor(0, orig_cursor)
    return
  end

  vim.notify("No fold under cursor", vim.log.levels.INFO)
end

-- ========================
-- Commands & autocmds
-- ========================
api.nvim_create_user_command("ToggleAllFolds", toggle_all_folds, { desc = "Toggle all folds open/closed" })
api.nvim_create_user_command("ToggleFold", toggle_fold_under_cursor, { desc = "Toggle fold under cursor" })
api.nvim_create_user_command("PeekFold", peek_fold, { desc = "Preview fold contents" })

-- Apply folding on FileType (safe: buffer provided)
api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(ensure_folding_for_filetype, args.buf)
  end,
  desc = "Ensure folding configured for buffer",
})

-- Reconfigure after Treesitter attaches (some TS setups emit user events)
api.nvim_create_autocmd("User", {
  pattern = "TSBufAttach",
  callback = function(args)
    pcall(ensure_folding_for_filetype, args.buf)
    pcall(refresh_folds, args.buf)
  end,
  desc = "Reconfigure folding after Treesitter attaches",
})

-- Also handle BufWinEnter to ensure settings are applied when a buffer gets a window
api.nvim_create_autocmd("BufWinEnter", {
  callback = function(args)
    pcall(ensure_folding_for_filetype, args.buf)
  end,
  desc = "Apply fold settings on buffer entering a window",
})

-- Export module
M.toggle_all_folds = toggle_all_folds
M.peek_fold = peek_fold
M.toggle_fold = toggle_fold_under_cursor
M.ensure_folding_for_filetype = ensure_folding_for_filetype

return M
