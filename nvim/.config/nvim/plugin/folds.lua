-- folds.lua
-- Minimal Treesitter-aware folding, UFO-like, single file.

if vim.g.loaded_folds_plugin then
  return
end
vim.g.loaded_folds_plugin = true

local api, fn, cmd = vim.api, vim.fn, vim.cmd
local M = {}

-- ========================
-- Config
-- ========================
M.config = {
  excluded_filetypes = { "help", "terminal", "dashboard", "NvimTree", "lazy" },
  max_file_lines = 20000,
  ft_fallback = { python = "indent", yaml = "indent" },
}

function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      M.config[k] = v
    end
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

local function ensure_folding(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  if is_excluded(ft) then
    pcall(api.nvim_set_option_value, "foldenable", false, { buf = bufnr })
    return
  end

  local opts = { buf = bufnr }
  if has_ts_parser(ft) then
    pcall(api.nvim_set_option_value, "foldmethod", "expr", opts)
    pcall(api.nvim_set_option_value, "foldexpr", "nvim_treesitter#foldexpr()", opts)
  else
    local method = M.config.ft_fallback[ft] or "syntax"
    pcall(api.nvim_set_option_value, "foldmethod", method, opts)
    pcall(api.nvim_set_option_value, "foldexpr", "", opts)
  end

  pcall(api.nvim_set_option_value, "foldenable", true, opts)
  pcall(api.nvim_set_option_value, "foldlevel", 99, opts)
end

-- ========================
-- Toggle / Peek
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

function M.toggle_all_folds()
  local bufnr = api.nvim_get_current_buf()
  ensure_folding(bufnr)
  local cursor = api.nvim_win_get_cursor(0)
  if any_folds_closed(bufnr) then
    pcall(cmd, "silent! normal! zR")
  else
    pcall(cmd, "silent! normal! zM")
  end
  api.nvim_win_set_cursor(0, cursor)
end

function M.toggle_fold()
  local bufnr = api.nvim_get_current_buf()
  ensure_folding(bufnr)
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)
  local cursor = api.nvim_win_get_cursor(0)

  if fold_start ~= -1 then
    api.nvim_win_set_cursor(0, { fold_start, 0 })
    pcall(cmd, "silent! normal! zo")
    api.nvim_win_set_cursor(0, cursor)
    return
  end

  local fold_level = fn.foldlevel(line)
  if fold_level > 0 then
    local l = line
    while l > 1 and fn.foldlevel(l - 1) >= fold_level do
      l = l - 1
    end
    api.nvim_win_set_cursor(0, { l, 0 })
    pcall(cmd, "silent! normal! zc")
    api.nvim_win_set_cursor(0, cursor)
    return
  end

  vim.notify("No fold under cursor", vim.log.levels.INFO)
end

-- Peek fold under cursor
local peek_win
function M.peek_fold()
  local bufnr = api.nvim_get_current_buf()
  ensure_folding(bufnr)
  local line = fn.line "."
  local fold_start = fn.foldclosed(line)
  if peek_win and api.nvim_win_is_valid(peek_win) then
    pcall(api.nvim_win_close, peek_win, true)
    peek_win = nil
    return
  end
  if fold_start == -1 then
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
  api.nvim_buf_set_option(buf, "modifiable", false)

  local w, h = api.nvim_get_option_value("columns", {}), api.nvim_get_option_value("lines", {})
  local width = math.floor(w * 0.6)
  local height = math.min(#lines, math.floor(h * 0.5))

  peek_win = api.nvim_open_win(buf, false, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
    noautocmd = true,
  })
  pcall(api.nvim_set_option_value, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = peek_win })

  local close = function()
    if peek_win and api.nvim_win_is_valid(peek_win) then
      api.nvim_win_close(peek_win, true)
    end
    peek_win = nil
  end
  api.nvim_create_autocmd({ "BufLeave", "WinScrolled", "InsertEnter", "WinLeave" }, { once = true, callback = close })
  pcall(vim.keymap.set, "n", "q", close, { buffer = buf, silent = true })
  pcall(vim.keymap.set, "n", "<Esc>", close, { buffer = buf, silent = true })
end

-- ========================
-- Commands / Autocmd
-- ========================
api.nvim_create_user_command("ToggleAllFolds", M.toggle_all_folds, { desc = "Toggle all folds" })
api.nvim_create_user_command("ToggleFold", M.toggle_fold, { desc = "Toggle fold under cursor" })
api.nvim_create_user_command("PeekFold", M.peek_fold, { desc = "Peek fold contents" })

api.nvim_create_autocmd({ "BufWinEnter", "FileType", "User" }, {
  callback = function(args)
    ensure_folding(args.buf)
  end,
})

return M
