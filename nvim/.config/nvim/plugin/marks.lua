-- marks.lua  (~/.config/nvim/plugin/marks.lua)
-- Lightweight harpoon-style file-list plugin
-- Only implements the two operations you actually use:
--   add current file to the list
--   open/close the quick-menu to reorder / remove files
--
-- Keymaps (remap freely at the bottom of this file):
--   <leader>a  → add current file
--   <leader>e  → toggle quick-menu

local M = {}

-- ── persistence ───────────────────────────────────────────────────────────────
local data_dir = vim.fn.stdpath "data" .. "/marks_plugin"
local data_file = data_dir .. "/list.json"

local function ensure_dir()
  vim.fn.mkdir(data_dir, "p")
end

local function load_list()
  local ok, raw = pcall(vim.fn.readfile, data_file)
  if not ok or #raw == 0 then
    return {}
  end
  local decoded = vim.fn.json_decode(table.concat(raw, "\n"))
  return type(decoded) == "table" and decoded or {}
end

local function save_list(list)
  ensure_dir()
  vim.fn.writefile({ vim.fn.json_encode(list) }, data_file)
end

-- ── state ─────────────────────────────────────────────────────────────────────
local list = load_list() -- list of absolute file paths (strings)

-- ── helpers ───────────────────────────────────────────────────────────────────
local function normalize(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function index_of(path)
  local p = normalize(path)
  for i, v in ipairs(list) do
    if v == p then
      return i
    end
  end
  return nil
end

-- ── add ───────────────────────────────────────────────────────────────────────
function M.add()
  local path = normalize(vim.api.nvim_buf_get_name(0))
  if path == "" then
    vim.notify("marks: buffer has no file name", vim.log.levels.WARN)
    return
  end
  if index_of(path) then
    vim.notify("marks: already in list — " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.INFO)
    return
  end
  table.insert(list, path)
  save_list(list)
  vim.notify(string.format("marks: added [%d] %s", #list, vim.fn.fnamemodify(path, ":~:.")), vim.log.levels.INFO)
end

-- ── quick-menu ────────────────────────────────────────────────────────────────
local menu_buf = nil
local menu_win = nil
local menu_open = false

local function close_menu()
  if menu_win and vim.api.nvim_win_is_valid(menu_win) then
    vim.api.nvim_win_close(menu_win, true)
  end
  if menu_buf and vim.api.nvim_buf_is_valid(menu_buf) then
    vim.api.nvim_buf_delete(menu_buf, { force = true })
  end
  menu_buf = nil
  menu_win = nil
  menu_open = false
end

-- Commit whatever is in the menu buffer back to `list` and save.
local function commit_menu()
  if not (menu_buf and vim.api.nvim_buf_is_valid(menu_buf)) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)
  local new_list = {}
  for _, line in ipairs(lines) do
    local trimmed = line:match "^%s*(.-)%s*$"
    if trimmed ~= "" then
      -- expand ~ back to absolute path
      local abs = vim.fn.expand(trimmed)
      table.insert(new_list, abs)
    end
  end
  list = new_list
  save_list(list)
end

local function open_menu()
  -- Build display lines (show paths relative to cwd with ~ abbreviation)
  local lines = {}
  for _, path in ipairs(list) do
    table.insert(lines, vim.fn.fnamemodify(path, ":~:."))
  end

  -- Create scratch buffer
  menu_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, lines)
  vim.bo[menu_buf].buftype = "acwrite"
  vim.bo[menu_buf].bufhidden = "wipe"
  vim.bo[menu_buf].filetype = "marks_menu"
  vim.bo[menu_buf].swapfile = false

  -- Floating window dimensions
  local width = math.max(40, math.floor(vim.o.columns * 0.45))
  local height = math.max(4, math.min(#lines + 2, math.floor(vim.o.lines * 0.4)))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  menu_win = vim.api.nvim_open_win(menu_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " marks ",
    title_pos = "center",
  })

  vim.wo[menu_win].cursorline = true
  menu_open = true

  -- ── menu keymaps ────────────────────────────────────────────────────────────

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = menu_buf, nowait = true, desc = desc })
  end

  -- <CR> – open file under cursor and close menu
  map("<CR>", function()
    local idx = vim.api.nvim_win_get_cursor(menu_win)[1]
    local line = vim.api.nvim_buf_get_lines(menu_buf, idx - 1, idx, false)[1] or ""
    local path = vim.fn.expand(line:match "^%s*(.-)%s*$")
    commit_menu()
    close_menu()
    if path ~= "" then
      vim.cmd("edit " .. vim.fn.fnameescape(path))
    end
  end, "marks: open file")

  -- dd  – delete line (built-in), changes are committed on close
  -- <leader>e or q or <Esc> – close and save
  local function save_and_close()
    commit_menu()
    close_menu()
  end

  map("q", save_and_close, "marks: close menu")
  map("<Esc>", save_and_close, "marks: close menu")
  map("<leader>e", save_and_close, "marks: close menu")

  -- BufWriteCmd so that :w inside the float also commits
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = menu_buf,
    callback = function()
      commit_menu()
      vim.bo[menu_buf].modified = false
      vim.notify("marks: list saved", vim.log.levels.INFO)
    end,
  })

  -- Auto-commit if the window is closed by any other means (e.g. :q)
  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    buffer = menu_buf,
    once = true,
    callback = function()
      commit_menu()
      menu_buf = nil
      menu_win = nil
      menu_open = false
    end,
  })
end

-- ── toggle ────────────────────────────────────────────────────────────────────
function M.toggle_quick_menu()
  if menu_open then
    commit_menu()
    close_menu()
  else
    open_menu()
  end
end

-- ── keymaps ───────────────────────────────────────────────────────────────────
vim.keymap.set("n", "<leader>a", M.add, { desc = "marks: add file", silent = true })
vim.keymap.set("n", "<leader>ha", M.toggle_quick_menu, { desc = "marks: toggle quick-menu", silent = true })

return M
