-- marks.lua (~/.config/nvim/plugin/marks.lua)
-- Lightweight harpoon-style file-list plugin

-- ── path & persistence ────────────────────────────────────────────────────────
local data_dir = vim.fn.stdpath "data" .. "/marks_plugin"

local function normalize(path)
  return vim.fn.fnamemodify(path, ":p")
end

-- Determines whether to use a project-specific file or the global one
local function get_data_file()
  local buf_path = vim.api.nvim_buf_get_name(0)
  -- Start searching from the buffer's directory, fallback to CWD if empty
  local search_path = buf_path ~= "" and vim.fn.fnamemodify(buf_path, ":p:h") or vim.fn.getcwd()

  -- Find nearest .git root upwards
  local git_root = vim.fs.root(search_path, ".git")

  if git_root then
    -- Sanitize path to use as a valid filename (replaces slashes/colons with underscores)
    local safe_name = git_root:gsub("[\\/:]", "_")
    return data_dir .. "/list_" .. safe_name .. ".json"
  else
    return data_dir .. "/list_global.json"
  end
end

local function load_list(file_path)
  local ok, raw = pcall(vim.fn.readfile, file_path)
  if not ok or #raw == 0 then
    return {}
  end
  local decoded = vim.fn.json_decode(table.concat(raw, "\n"))
  return type(decoded) == "table" and decoded or {}
end

local function save_list(list, file_path)
  vim.fn.mkdir(data_dir, "p")
  vim.fn.writefile({ vim.fn.json_encode(list) }, file_path)
end

local function index_of(list, path)
  local p = normalize(path)
  for i, v in ipairs(list) do
    if v == p then
      return i
    end
  end
  return nil
end

-- ── core actions ──────────────────────────────────────────────────────────────
local function marks_add()
  local path = normalize(vim.api.nvim_buf_get_name(0))
  if path == "" then
    vim.notify("marks: buffer has no file name", vim.log.levels.WARN)
    return
  end

  local df = get_data_file()
  local list = load_list(df)

  if index_of(list, path) then
    vim.notify("marks: already in list — " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
    return
  end

  table.insert(list, path)
  save_list(list, df)
  vim.notify(string.format("marks: added [%d] %s", #list, vim.fn.fnamemodify(path, ":~")), vim.log.levels.INFO)
end

local function marks_delete()
  local path = normalize(vim.api.nvim_buf_get_name(0))
  if path == "" then
    return
  end

  local df = get_data_file()
  local list = load_list(df)
  local idx = index_of(list, path)

  if idx then
    table.remove(list, idx)
    save_list(list, df)
    vim.notify("marks: removed " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
  else
    vim.notify("marks: not in list", vim.log.levels.WARN)
  end
end

-- ── quick-menu ────────────────────────────────────────────────────────────────
local menu_buf = nil
local menu_win = nil
local menu_open = false
local active_data_file = nil

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
  active_data_file = nil
end

local function commit_menu()
  if not (menu_buf and vim.api.nvim_buf_is_valid(menu_buf)) or not active_data_file then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)
  local new_list = {}
  for _, line in ipairs(lines) do
    local trimmed = line:match "^%s*(.-)%s*$"
    if trimmed ~= "" then
      table.insert(new_list, vim.fn.expand(trimmed))
    end
  end
  save_list(new_list, active_data_file)
end

local function open_menu()
  active_data_file = get_data_file()
  local list = load_list(active_data_file)
  local lines = {}

  for _, path in ipairs(list) do
    table.insert(lines, vim.fn.fnamemodify(path, ":~"))
  end

  menu_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, lines)
  vim.bo[menu_buf].buftype = "acwrite"
  vim.bo[menu_buf].bufhidden = "wipe"
  vim.bo[menu_buf].filetype = "marks_menu"
  vim.bo[menu_buf].swapfile = false

  local width = math.max(40, math.floor(vim.o.columns * 0.45))
  local height = math.max(4, math.min(#lines + 2, math.floor(vim.o.lines * 0.4)))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local title = active_data_file:match "list_global" and " marks (global) " or " marks (project) "

  menu_win = vim.api.nvim_open_win(menu_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  vim.wo[menu_win].cursorline = true
  menu_open = true

  -- menu keymaps
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = menu_buf, nowait = true, desc = desc })
  end

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

  local function save_and_close()
    commit_menu()
    close_menu()
  end

  map("q", save_and_close, "marks: close menu")
  map("<Esc>", save_and_close, "marks: close menu")

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = menu_buf,
    callback = function()
      commit_menu()
      vim.bo[menu_buf].modified = false
      vim.notify("marks: list saved", vim.log.levels.INFO)
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    buffer = menu_buf,
    once = true,
    callback = function()
      commit_menu()
      menu_buf = nil
      menu_win = nil
      menu_open = false
      active_data_file = nil
    end,
  })
end

-- ── toggle ────────────────────────────────────────────────────────────────────
local function marks_toggle()
  if menu_open then
    commit_menu()
    close_menu()
  else
    open_menu()
  end
end

-- ── Commands ──────────────────────────────────────────────────────────────────
vim.api.nvim_create_user_command("MarksAdd", marks_add, { desc = "Add current file to marks" })
vim.api.nvim_create_user_command("MarksDelete", marks_delete, { desc = "Remove current file from marks" })
vim.api.nvim_create_user_command("MarksToggle", marks_toggle, { desc = "Toggle marks quick-menu" })
