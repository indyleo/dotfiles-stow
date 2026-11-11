-- plugin/dashboard.lua
-- Startup dashboard shown when Neovim opens with no file arguments.
--
-- Integrates with existing config:
--   FzfLua (files/oldfiles/live_grep) · Sessions · Marks · Lf
--   PackUpdate · checkhealth · SessionPick
--
-- Usage:
--   :Dashboard              open from anywhere
--   <leader>H               global keymap (space + H)
--   f r g n s m e c u h q   menu shortcuts on dashboard
--   <CR> / 1-9              open recent file N
--   <C-r>                   refresh dashboard
--   q                       quit Neovim (dashboard only)
--
-- ─────────────────────────────────────────────────────────────────────────────

if vim.g.loaded_dashboard_plugin then
  return
end
vim.g.loaded_dashboard_plugin = true

local api = vim.api
local fn = vim.fn

local ns = api.nvim_create_namespace "dashboard"

-- ── Palette (fallback = gruvbox dark; overridden by theme.lua) ───────────────
local fallback = {
  bg0 = "#282828",
  bg1 = "#3c3836",
  bg2 = "#504945",
  bg3 = "#665c54",
  bg4 = "#7c6f64",
  fg0 = "#fbf1c7",
  fg1 = "#ebdbb2",
  fg2 = "#d5c4a1",
  fg3 = "#bdae93",
  fg4 = "#a89984",
  red = "#fb4934",
  green = "#b8bb26",
  yellow = "#fabd2f",
  blue = "#83a598",
  purple = "#d3869b",
  aqua = "#8ec07c",
  orange = "#fe8019",
  gray = "#928374",
}

local function palette()
  return _G.__colorscheme_palette or fallback
end

-- ── Highlights ──────────────────────────────────────────────────────────────
local function apply_highlights()
  local c = palette()
  local groups = {
    DbHeader = { fg = c.orange, bold = true },
    DbSubtitle = { fg = c.gray },
    DbIcon = { fg = c.aqua },
    DbBracket = { fg = c.bg4 },
    DbKey = { fg = c.yellow, bold = true },
    DbDesc = { fg = c.fg1 },
    DbSection = { fg = c.purple, bold = true },
    DbPathIdx = { fg = c.bg4 },
    DbPath = { fg = c.blue },
    DbFooter = { fg = c.fg4 },
  }
  for name, hl in pairs(groups) do
    api.nvim_set_hl(0, name, hl)
  end
end

-- ── Content ─────────────────────────────────────────────────────────────────
local function get_header(width)
  if width < 62 then
    return { " NEOVIM " }
  end
  return {
    "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
    "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
    "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
    "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
    "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
    "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
  }
end

local function get_menu()
  return {
    { key = "f", icon = "", desc = "Find file", cmd = "FzfLua files" },
    { key = "r", icon = "", desc = "Recent files", cmd = "FzfLua oldfiles" },
    { key = "g", icon = "", desc = "Grep project", cmd = "FzfLua live_grep" },
    { key = "n", icon = "", desc = "New file", cmd = "enew" },
    { key = "s", icon = "", desc = "Sessions", cmd = "SessionPick" },
    { key = "m", icon = "", desc = "Marks", cmd = "MarksToggle" },
    { key = "e", icon = "", desc = "File manager", cmd = "Lf" },
    { key = "c", icon = "", desc = "Edit config", cmd = "edit $MYVIMRC" },
    { key = "u", icon = "", desc = "Update plugins", cmd = "PackUpdate" },
    { key = "h", icon = "", desc = "Health check", cmd = "checkhealth" },
    { key = "q", icon = "", desc = "Quit", cmd = "qa" },
  }
end

local function get_recent(max)
  max = max or 6
  local out, seen = {}, {}
  for _, f in ipairs(vim.v.oldfiles) do
    if fn.filereadable(f) == 1 and not seen[f] then
      seen[f] = true
      out[#out + 1] = f
      if #out >= max then
        break
      end
    end
  end
  return out
end

local function truncate_tail(str, max_w)
  if max_w < 3 then
    return ""
  end
  if fn.strdisplaywidth(str) <= max_w then
    return str
  end
  local chars = fn.strchars(str)
  local out = str
  while chars > 0 and fn.strdisplaywidth(out) > max_w - 1 do
    chars = chars - 1
    out = fn.strcharpart(str, -chars)
  end
  return "…" .. out
end

-- ── Build buffer contents ───────────────────────────────────────────────────
local function build(buf)
  local width = vim.o.columns
  local height = vim.o.lines - vim.o.cmdheight
  local lines, marks = {}, {}

  local function add(text, specs)
    lines[#lines + 1] = text
    local row = #lines - 1
    if specs then
      for _, s in ipairs(specs) do
        marks[#marks + 1] = { row, s[1], s[2], s[3] }
      end
    end
  end

  local menu_items = get_menu()
  local recent = get_recent(6)
  local per_row = width >= 62 and 2 or 1
  local col_w = per_row == 2 and 28 or 34
  local menu_rows = math.ceil(#menu_items / per_row)
  local recent_h = #recent > 0 and (#recent + 1) or 0
  local header = get_header(width)

  local total_h = #header + 3 + menu_rows + 4 + recent_h + 4
  local top_pad = math.max(1, math.floor((height - total_h) / 2))
  for _ = 1, top_pad do
    add ""
  end

  -- Header
  local header_w = fn.strdisplaywidth(header[1])
  local header_pad = math.max(0, math.floor((width - header_w) / 2))
  local header_space = string.rep(" ", header_pad)
  for _, line in ipairs(header) do
    add(header_space .. line, { { #header_space, #header_space + #line, "DbHeader" } })
  end

  -- Subtitle: version + cwd
  add ""
  local version = "v" .. vim.version().major .. "." .. vim.version().minor
  local cwd = fn.fnamemodify(fn.getcwd(), ":~")
  local subtitle = " " .. version .. "   " .. cwd .. " "
  local sub_pad = math.max(0, math.floor((width - fn.strdisplaywidth(subtitle)) / 2))
  local sub_space = string.rep(" ", sub_pad)
  add(sub_space .. subtitle, { { #sub_space, #sub_space + #subtitle, "DbSubtitle" } })

  add ""
  add ""

  -- Menu
  local menu_w = col_w * per_row
  local menu_pad = math.max(0, math.floor((width - menu_w) / 2))
  local menu_space = string.rep(" ", menu_pad)

  for r = 1, menu_rows do
    local line = menu_space
    local specs = {}
    for c = 1, per_row do
      local item = menu_items[(r - 1) * per_row + c]
      if item then
        local icon_start = #line
        local icon_end = icon_start + #item.icon
        local op_open = icon_end + 1
        local op_open_end = op_open + 1
        local key_start = op_open_end
        local key_end = key_start + #item.key
        local op_close = key_end
        local op_close_end = op_close + 1
        local desc_start = op_close_end + 1
        local desc_end = desc_start + #item.desc

        local chunk = item.icon .. " [" .. item.key .. "] " .. item.desc
        local chunk_w = fn.strdisplaywidth(chunk)
        line = line .. chunk .. string.rep(" ", math.max(1, col_w - chunk_w))

        specs[#specs + 1] = { icon_start, icon_end, "DbIcon" }
        specs[#specs + 1] = { op_open, op_open_end, "DbBracket" }
        specs[#specs + 1] = { key_start, key_end, "DbKey" }
        specs[#specs + 1] = { op_close, op_close_end, "DbBracket" }
        specs[#specs + 1] = { desc_start, desc_end, "DbDesc" }
      end
    end
    add(line, specs)
  end

  -- Recent files
  if #recent > 0 then
    add ""
    local section = "── Recent ──"
    local sec_w = fn.strdisplaywidth(section)
    local sec_pad = math.max(0, math.floor((width - sec_w) / 2))
    local sec_space = string.rep(" ", sec_pad)
    add(sec_space .. section, { { #sec_space, #sec_space + #section, "DbSection" } })

    for i, path in ipairs(recent) do
      local idx = string.format("%d. ", i)
      local short = truncate_tail(fn.fnamemodify(path, ":~"), math.min(60, width - 12))
      local line_w = fn.strdisplaywidth(idx) + fn.strdisplaywidth(short)
      local pad = string.rep(" ", math.max(0, math.floor((width - line_w) / 2)))
      local start = #pad
      add(pad .. idx .. short, {
        { start, start + #idx, "DbPathIdx" },
        { start + #idx, start + #idx + #short, "DbPath" },
      })
    end
  end

  -- Footer
  add ""
  add ""
  local footer = "  [Enter] open first  ·  [q] quit  ·  [:] command  "
  local foot_pad = math.max(0, math.floor((width - #footer) / 2))
  local foot_space = string.rep(" ", foot_pad)
  add(foot_space .. footer, { { #foot_space, #foot_space + #footer, "DbFooter" } })

  vim.b[buf].dashboard_recent = recent
  return lines, marks
end

-- ── Render ──────────────────────────────────────────────────────────────────
local function render(buf)
  buf = buf or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local lines, marks = build(buf)

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(api.nvim_buf_add_highlight, buf, ns, m[4], m[1], m[2], m[3])
  end

  if api.nvim_get_current_buf() == buf then
    pcall(api.nvim_win_set_cursor, 0, { math.min(#lines, 10), 0 })
  end
end

-- ── Window / buffer setup ───────────────────────────────────────────────────
local function setup_buffer(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "dashboard"
  vim.bo[buf].modifiable = false
end

-- These options are window-local. Save them before applying dashboard styling,
-- then restore them when the dashboard buffer is left.
local window_options = {
  "number",
  "relativenumber",
  "signcolumn",
  "statuscolumn",
  "foldcolumn",
  "foldenable",
  "wrap",
  "cursorline",
  "spell",
  "list",
  "colorcolumn",
}

local function save_window_options(win)
  local saved = {}
  for _, name in ipairs(window_options) do
    local ok, value = pcall(api.nvim_get_option_value, name, { win = win })
    if ok then
      saved[name] = value
    end
  end
  return saved
end

local function restore_window_options(win, saved)
  if not api.nvim_win_is_valid(win) or not saved then
    return
  end

  for name, value in pairs(saved) do
    pcall(api.nvim_set_option_value, name, value, { win = win })
  end
end

local function setup_window_options()
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.statuscolumn = ""
  vim.wo.foldcolumn = "0"
  vim.wo.foldenable = false
  vim.wo.wrap = false
  vim.wo.cursorline = false
  vim.wo.spell = false
  vim.wo.list = false
  vim.wo.colorcolumn = ""
end

-- ── Keymaps ─────────────────────────────────────────────────────────────────
local function run(cmd)
  local ok, err = pcall(vim.cmd, cmd)
  if not ok then
    vim.notify("Dashboard: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function setup_keymaps(buf)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc = "Dashboard: " .. desc,
    })
  end

  for _, item in ipairs(get_menu()) do
    map(item.key, function()
      run(item.cmd)
    end, item.desc)
  end

  map("<CR>", function()
    local recent = vim.b.dashboard_recent or {}
    if recent[1] then
      run("edit " .. fn.fnameescape(recent[1]))
    end
  end, "open most recent")

  for i = 1, 9 do
    map(tostring(i), function()
      local recent = vim.b.dashboard_recent or {}
      if recent[i] then
        run("edit " .. fn.fnameescape(recent[i]))
      end
    end, "open recent #" .. i)
  end

  map("<C-r>", function()
    render(buf)
  end, "refresh")
  map("<Esc>", "<cmd>noh<CR>", "clear search")
end

-- ── Public entry point ──────────────────────────────────────────────────────
local M = {}

function M.open()
  apply_highlights()

  if vim.bo.filetype == "dashboard" then
    render()
    return
  end

  local win = api.nvim_get_current_win()
  local saved_options = save_window_options(win)
  local orig_buf = api.nvim_get_current_buf()
  local buf = api.nvim_create_buf(false, true)
  setup_buffer(buf)
  api.nvim_set_current_buf(buf)

  -- Restore the user's normal editing options as soon as they leave the
  -- dashboard. This brings back sign/status columns and fold indicators.
  api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      restore_window_options(win, saved_options)
    end,
    desc = "Restore window options after leaving dashboard",
  })

  setup_window_options()
  setup_keymaps(buf)
  render(buf)

  -- Wipe the empty startup buffer we just left (only if it's a virgin buffer)
  if orig_buf ~= buf and api.nvim_buf_is_valid(orig_buf) and api.nvim_buf_get_name(orig_buf) == "" and not vim.bo[orig_buf].modified then
    pcall(api.nvim_buf_delete, orig_buf, { force = false })
  end
end

function M.refresh()
  if vim.bo.filetype == "dashboard" then
    render()
  end
end

-- ── Auto-open on VimEnter ───────────────────────────────────────────────────
local function should_open()
  if vim.g.dashboard_disable then
    return false
  end
  if fn.argc() > 0 then
    return false
  end
  if vim.v.this_session ~= "" then
    return false
  end

  local buf = api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  if api.nvim_buf_get_name(buf) ~= "" then
    return false
  end
  if api.nvim_buf_line_count(buf) > 1 then
    return false
  end
  if (api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") ~= "" then
    return false
  end

  return true
end

api.nvim_create_autocmd("VimEnter", {
  group = api.nvim_create_augroup("DashboardAuto", { clear = true }),
  callback = function()
    -- Defer one tick so other plugins (which-key, statusline, ...) settle first
    vim.schedule(function()
      if should_open() then
        M.open()
      end
    end)
  end,
})

-- Re-render on resize / theme change
api.nvim_create_autocmd("VimResized", {
  group = api.nvim_create_augroup("DashboardResize", { clear = true }),
  callback = function()
    local buf = api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "dashboard" then
      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) and api.nvim_get_current_buf() == buf and vim.bo[buf].filetype == "dashboard" then
          render(buf)
        end
      end)
    end
  end,
})

api.nvim_create_autocmd("ColorScheme", {
  group = api.nvim_create_augroup("DashboardTheme", { clear = true }),
  callback = function()
    local buf = api.nvim_get_current_buf()
    vim.schedule(function()
      apply_highlights()
      if api.nvim_buf_is_valid(buf) and api.nvim_get_current_buf() == buf and vim.bo[buf].filetype == "dashboard" then
        render(buf)
      end
    end)
  end,
})

-- ── Commands & keymaps ──────────────────────────────────────────────────────
api.nvim_create_user_command("Dashboard", M.open, { desc = "Open startup dashboard" })
api.nvim_create_user_command("DashboardRefresh", M.refresh, { desc = "Refresh dashboard" })

vim.keymap.set("n", "<leader>H", M.open, { desc = "Open dashboard" })

return M
