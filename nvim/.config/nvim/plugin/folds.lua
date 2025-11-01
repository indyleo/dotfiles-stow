-- folds.lua
-- Minimal Treesitter-aware folding plugin for nvim/plugin (single-file)
-- Refactored for better performance, readability, and robustness

if vim.g.loaded_folds_plugin then
  return
end
vim.g.loaded_folds_plugin = true

local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local M = {}

-- ========================
-- Default Config
-- ========================
M.config = {
  excluded_filetypes = { "help", "terminal", "dashboard", "NvimTree", "lazy" },
  max_file_lines = 20000,
  ft_fallback = { python = "indent", yaml = "indent" },
  foldlevel = 99,
  -- NEW: Treesitter parsing delay
  ts_fold_delay = 500, -- ms to wait for treesitter parsing (increase for slow machines)
  auto_refresh_folds = true, -- automatically refresh folds on text changes
  fold_refresh_debounce = 500, -- ms to wait after typing before refreshing folds
  peek = {
    width_percent = 0.60,
    height_percent = 0.50,
    max_height = 30, -- NEW: prevent giant peek windows
    border = "rounded",
    close_keys = { "q", "<Esc>" },
    show_line_numbers = true, -- NEW: optional line numbers in peek
  },
  -- NEW: Performance optimization
  cache_ts_check = true, -- cache treesitter availability per filetype
  batch_fold_check_size = 100, -- check folds in batches for large files
}

-- ========================
-- Setup
-- ========================
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- ========================
-- Utilities
-- ========================
local ts_parsers = nil
local ts_cache = {} -- NEW: cache treesitter checks per filetype

local function load_ts_parsers_once()
  if ts_parsers ~= nil then
    return ts_parsers
  end
  local ok, p = pcall(require, "nvim-treesitter.parsers")
  ts_parsers = (ok and p and p.has_parser) and p or false
  return ts_parsers
end

local function has_ts_parser(ft)
  if not ft or ft == "" then
    return false
  end

  -- Use cache if enabled
  if M.config.cache_ts_check and ts_cache[ft] ~= nil then
    return ts_cache[ft]
  end

  local p = load_ts_parsers_once()
  local has_parser = p and p.has_parser and p.has_parser(ft) or false

  if M.config.cache_ts_check then
    ts_cache[ft] = has_parser
  end

  return has_parser
end

local function is_excluded(ft)
  return ft and vim.tbl_contains(M.config.excluded_filetypes, ft)
end

local function safe_buf_valid_loaded(bufnr)
  return bufnr and api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

-- NEW: Centralized buffer option setter with better error handling
local function set_buf_options(bufnr, options)
  for opt, value in pairs(options) do
    local ok, err = pcall(api.nvim_set_option_value, opt, value, { buf = bufnr })
    if not ok and vim.log.levels.DEBUG then
      vim.notify(string.format("Failed to set %s: %s", opt, err), vim.log.levels.DEBUG)
    end
  end
end

-- NEW: Check if buffer has foldmethod enabled
local function has_folding_enabled(bufnr)
  local ok, enabled = pcall(api.nvim_get_option_value, "foldenable", { buf = bufnr })
  return ok and enabled
end

-- ========================
-- Ensure folding
-- ========================
local function ensure_folding(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not safe_buf_valid_loaded(bufnr) then
    return false
  end

  local line_count = api.nvim_buf_line_count(bufnr)
  local max_lines = M.config.max_file_lines

  -- Early exit for large files
  if line_count > max_lines then
    set_buf_options(bufnr, { foldenable = false })
    return false
  end

  local ft = api.nvim_get_option_value("filetype", { buf = bufnr })

  -- Early exit for excluded filetypes
  if is_excluded(ft) then
    set_buf_options(bufnr, { foldenable = false })
    return false
  end

  -- Configure folding based on treesitter availability
  local fold_options = { foldenable = true, foldlevel = M.config.foldlevel }

  if has_ts_parser(ft) then
    fold_options.foldmethod = "expr"
    fold_options.foldexpr = "nvim_treesitter#foldexpr()"
  else
    local method = (M.config.ft_fallback and M.config.ft_fallback[ft]) or "syntax"
    fold_options.foldmethod = method
    fold_options.foldexpr = "" -- Clear expr for non-expr methods
  end

  set_buf_options(bufnr, fold_options)
  return true
end

-- NEW: Wait for Treesitter to finish parsing before enabling folds
local function ensure_folding_with_ts_wait(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not safe_buf_valid_loaded(bufnr) then
    return
  end

  local ft = api.nvim_get_option_value("filetype", { buf = bufnr })

  -- For Treesitter-based folding, wait for parse to complete
  if has_ts_parser(ft) then
    -- Try to get the parser
    local ok, ts_parsers = pcall(require, "nvim-treesitter.parsers")
    if ok and ts_parsers then
      -- Schedule folding setup after a short delay to let TS parse
      vim.defer_fn(function()
        if safe_buf_valid_loaded(bufnr) then
          ensure_folding(bufnr)
        end
      end, M.config.ts_fold_delay or 100) -- Configurable delay
      return
    end
  end

  -- For non-TS files, setup immediately
  ensure_folding(bufnr)
end

-- ========================
-- Fold helpers (OPTIMIZED)
-- ========================
local function any_folds_closed(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not safe_buf_valid_loaded(bufnr) or not has_folding_enabled(bufnr) then
    return false
  end

  local last = api.nvim_buf_line_count(bufnr)
  local max_lines = M.config.max_file_lines

  if last > max_lines then
    return false
  end

  -- OPTIMIZATION: Early exit + skip checking inside closed folds
  local l = 1
  while l <= last do
    local fold_start = fn.foldclosed(l)
    if fold_start ~= -1 then
      -- Found a closed fold!
      return true
    end
    l = l + 1
  end

  return false
end

-- NEW: Get fold info at cursor (reduces duplicate API calls)
local function get_fold_info(line)
  line = line or fn.line "."
  local fold_start = fn.foldclosed(line)
  local fold_end = fn.foldclosedend(line)

  return {
    line = line,
    is_closed = fold_start ~= -1,
    is_foldable = fold_end ~= -1,
    start_line = fold_start ~= -1 and fold_start or fn.foldclosed(line),
    end_line = fold_end,
  }
end

-- ========================
-- Toggle All Folds (IMPROVED)
-- ========================
function M.toggle_all_folds()
  local bufnr = api.nvim_get_current_buf()

  if not ensure_folding(bufnr) then
    vim.notify("Folding not available for this buffer", vim.log.levels.WARN)
    return
  end

  local cursor = api.nvim_win_get_cursor(0)

  -- Better approach: Check foldlevel instead of scanning all folds
  local current_foldlevel = vim.wo.foldlevel
  local max_foldlevel = M.config.foldlevel or 99

  if current_foldlevel >= max_foldlevel then
    -- Folds are open (high foldlevel), close them
    vim.cmd "silent! normal! zM"
    vim.wo.foldlevel = 0
  else
    -- Folds are closed (low foldlevel), open them
    vim.cmd "silent! normal! zR"
    vim.wo.foldlevel = max_foldlevel
  end

  -- Restore cursor
  pcall(api.nvim_win_set_cursor, 0, cursor)
end

-- ========================
-- Toggle Fold Under Cursor (IMPROVED)
-- ========================
function M.toggle_fold()
  local bufnr = api.nvim_get_current_buf()

  if not ensure_folding(bufnr) then
    vim.notify("Folding not available for this buffer", vim.log.levels.WARN)
    return
  end

  local cursor = api.nvim_win_get_cursor(0)
  local fold = get_fold_info()

  -- Check if we're on a closed fold
  if fold.is_closed then
    vim.cmd "silent! normal! zo" -- open fold
    pcall(api.nvim_win_set_cursor, 0, cursor)
    return
  end

  -- Check if we're on an open fold (foldclosedend returns -1 if not in fold)
  -- We need to check if there's a fold at this line at all
  local fold_level = fn.foldlevel(fold.line)
  if fold_level > 0 then
    vim.cmd "silent! normal! zc" -- close fold
    pcall(api.nvim_win_set_cursor, 0, cursor)
    return
  end

  vim.notify("No fold under cursor", vim.log.levels.INFO)
end

-- ========================
-- Peek Fold (ENHANCED)
-- ========================
local peek_win, peek_buf

local function close_peek()
  if peek_win and api.nvim_win_is_valid(peek_win) then
    pcall(api.nvim_win_close, peek_win, true)
  end
  if peek_buf and api.nvim_buf_is_valid(peek_buf) then
    pcall(api.nvim_buf_delete, peek_buf, { force = true })
  end
  peek_win, peek_buf = nil, nil
end

function M.peek_fold()
  local bufnr = api.nvim_get_current_buf()

  if not ensure_folding(bufnr) then
    vim.notify("Folding not available for this buffer", vim.log.levels.WARN)
    return
  end

  -- Toggle peek window if already open
  if peek_win and api.nvim_win_is_valid(peek_win) then
    close_peek()
    return
  end

  local fold = get_fold_info()

  if not fold.is_closed then
    vim.notify("No closed fold under cursor", vim.log.levels.INFO)
    return
  end

  -- Get fold content
  local lines = fn.getline(fold.start_line, fold.end_line)
  if not lines or #lines == 0 then
    vim.notify("Fold is empty", vim.log.levels.WARN)
    return
  end

  -- Create peek buffer
  peek_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(peek_buf, 0, -1, false, lines)

  -- Set buffer options
  local buf_opts = {
    filetype = api.nvim_get_option_value("filetype", { buf = bufnr }),
    modifiable = false,
    bufhidden = "wipe",
  }

  if M.config.peek.show_line_numbers then
    buf_opts.number = true
  end

  set_buf_options(peek_buf, buf_opts)

  -- Calculate window dimensions
  local ui = api.nvim_list_uis()[1]
  if not ui then
    return
  end

  local width = math.floor(ui.width * M.config.peek.width_percent)
  local height = math.min(#lines, math.floor(ui.height * M.config.peek.height_percent), M.config.peek.max_height or 30)

  -- Create floating window
  peek_win = api.nvim_open_win(peek_buf, false, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = M.config.peek.border,
    noautocmd = true,
    title = string.format(" Fold Preview (%d lines) ", #lines),
    title_pos = "center",
  })

  -- Set window highlight
  pcall(api.nvim_set_option_value, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = peek_win })

  -- Set up keymaps for closing
  for _, key in ipairs(M.config.peek.close_keys) do
    vim.keymap.set("n", key, close_peek, {
      buffer = peek_buf,
      silent = true,
      nowait = true,
    })
  end

  -- Auto-close on various events
  local peek_augroup = api.nvim_create_augroup("FoldsPeek", { clear = true })
  api.nvim_create_autocmd({ "BufLeave", "WinScrolled", "InsertEnter", "WinLeave", "CursorMoved" }, {
    group = peek_augroup,
    buffer = bufnr, -- Attach to source buffer
    once = true,
    callback = close_peek,
  })
end

-- NEW: Cycle through folds in buffer
function M.next_fold()
  local line = fn.line "."
  local last = fn.line "$"

  -- Find next closed fold
  for l = line + 1, last do
    if fn.foldclosed(l) ~= -1 then
      api.nvim_win_set_cursor(0, { l, 0 })
      return
    end
  end

  vim.notify("No more closed folds below", vim.log.levels.INFO)
end

function M.prev_fold()
  local line = fn.line "."

  -- Find previous closed fold
  for l = line - 1, 1, -1 do
    if fn.foldclosed(l) ~= -1 then
      api.nvim_win_set_cursor(0, { l, 0 })
      return
    end
  end

  vim.notify("No closed folds above", vim.log.levels.INFO)
end

-- NEW: Get fold statistics for statusline integration
function M.get_fold_stats()
  local bufnr = api.nvim_get_current_buf()

  if not has_folding_enabled(bufnr) then
    return nil
  end

  local line = fn.line "."
  local fold_level = fn.foldlevel(line)
  local fold_closed = fn.foldclosed(line)

  return {
    level = fold_level,
    is_closed = fold_closed ~= -1,
    total_lines = api.nvim_buf_line_count(bufnr),
  }
end

-- NEW: Manually refresh folds (useful after big edits)
function M.refresh_folds()
  local bufnr = api.nvim_get_current_buf()
  local ft = api.nvim_get_option_value("filetype", { buf = bufnr })

  if has_ts_parser(ft) then
    -- Force Treesitter to re-evaluate folds
    vim.cmd "silent! normal! zx"
    vim.notify("Folds refreshed", vim.log.levels.INFO)
  else
    vim.notify("Not using Treesitter folds", vim.log.levels.WARN)
  end
end

-- ========================
-- Commands & Autocmd (ENHANCED)
-- ========================
api.nvim_create_user_command("ToggleAllFolds", M.toggle_all_folds, {
  desc = "Toggle all folds open/closed",
})

api.nvim_create_user_command("ToggleFold", M.toggle_fold, {
  desc = "Toggle fold under cursor",
})

api.nvim_create_user_command("PeekFold", M.peek_fold, {
  desc = "Peek at closed fold contents in floating window",
})

api.nvim_create_user_command("NextFold", M.next_fold, {
  desc = "Jump to next closed fold",
})

api.nvim_create_user_command("PrevFold", M.prev_fold, {
  desc = "Jump to previous closed fold",
})

api.nvim_create_user_command("FoldsRefresh", M.refresh_folds, {
  desc = "Manually refresh Treesitter folds",
})

-- IMPROVED: Use augroup for better organization and cleanup
local fold_augroup = api.nvim_create_augroup("FoldsPlugin", { clear = true })

api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = fold_augroup,
  callback = function(args)
    -- Defer to avoid race conditions with other plugins
    vim.schedule(function()
      if safe_buf_valid_loaded(args.buf) then
        ensure_folding_with_ts_wait(args.buf)
      end
    end)
  end,
})

-- NEW: Refresh folds when Treesitter re-parses
api.nvim_create_autocmd({ "User" }, {
  group = fold_augroup,
  pattern = "TSUpdate",
  callback = function(args)
    vim.defer_fn(function()
      if safe_buf_valid_loaded(args.buf) then
        -- Force fold refresh by toggling foldmethod
        local ok, method = pcall(api.nvim_get_option_value, "foldmethod", { buf = args.buf })
        if ok and method == "expr" then
          vim.cmd "silent! normal! zx" -- Update folds
        end
      end
    end, 50)
  end,
})

-- NEW: Refresh folds after text changes (debounced)
local fold_refresh_timers = {}
api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = fold_augroup,
  callback = function(args)
    -- Skip if auto-refresh is disabled
    if not M.config.auto_refresh_folds then
      return
    end

    local bufnr = args.buf

    -- Cancel existing timer for this buffer
    if fold_refresh_timers[bufnr] then
      vim.fn.timer_stop(fold_refresh_timers[bufnr])
    end

    -- Debounce: only refresh after configured delay
    local debounce = M.config.fold_refresh_debounce or 500
    fold_refresh_timers[bufnr] = vim.fn.timer_start(debounce, function()
      if safe_buf_valid_loaded(bufnr) then
        local ft = api.nvim_get_option_value("filetype", { buf = bufnr })
        if has_ts_parser(ft) then
          -- Force treesitter to update folds
          vim.schedule(function()
            if api.nvim_buf_is_valid(bufnr) then
              vim.cmd "silent! normal! zx" -- Update folds without changing cursor
            end
          end)
        end
      end
      fold_refresh_timers[bufnr] = nil
    end)
  end,
})

-- NEW: Refresh after LSP formatting or external changes
api.nvim_create_autocmd({ "BufWritePost", "LspAttach" }, {
  group = fold_augroup,
  callback = function(args)
    vim.defer_fn(function()
      if safe_buf_valid_loaded(args.buf) then
        local ft = api.nvim_get_option_value("filetype", { buf = args.buf })
        if has_ts_parser(ft) then
          vim.cmd "silent! normal! zx"
        end
      end
    end, 100)
  end,
})

-- NEW: Optionally expose cache clearing function
function M.clear_cache()
  ts_cache = {}
  ts_parsers = nil
  vim.notify("Fold plugin cache cleared", vim.log.levels.INFO)
end

api.nvim_create_user_command("FoldsClearCache", M.clear_cache, {
  desc = "Clear treesitter cache for fold plugin",
})

return M
