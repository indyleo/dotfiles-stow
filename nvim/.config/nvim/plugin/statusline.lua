-- ========================
-- THEME-AWARE STATUSLINE (Async Git + Diagnostics)
-- ========================
local api, fn, uv = vim.api, vim.fn, vim.loop or vim.uv

-- ========================
-- Theme reading with file watcher
-- ========================
local cache_home = os.getenv "XDG_CACHE_HOME" or (os.getenv "HOME" .. "/.cache")
local theme_file = cache_home .. "/theme"

local function read_theme(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local theme = f:read "*l"
  f:close()
  return theme and theme:lower()
end

local theme_current = read_theme(theme_file) or "gruvbox"

-- Watch theme file for changes
if uv.fs_stat(theme_file) then
  local fs_event = uv.new_fs_event()
  fs_event:start(
    theme_file,
    {},
    vim.schedule_wrap(function()
      theme_current = read_theme(theme_file) or "gruvbox"
      local colors = themes[theme_current] or themes.gruvbox
      for name, col in pairs(colors) do
        local group = "StatusLine" .. name:gsub("^%l", string.upper)
        vim.cmd(string.format("highlight! %s guifg=%s guibg=%s gui=bold", group, col.fg, col.bg))
      end
      vim.cmd.redrawstatus()
    end)
  )
end

-- ========================
-- Theme color definitions
-- ========================
local themes = {
  gruvbox = {
    normal = { fg = "#ebdbb2", bg = "#458588" },
    insert = { fg = "#ebdbb2", bg = "#b8bb26" },
    visual = { fg = "#ebdbb2", bg = "#d3869b" },
    replace = { fg = "#ebdbb2", bg = "#fb4934" },
    command = { fg = "#ebdbb2", bg = "#fe8019" },
    terminal = { fg = "#ebdbb2", bg = "#689d6a" },
    inactive = { fg = "#a89984", bg = "#3c3836" },
    git = { fg = "#b8bb26", bg = "#282828" },
    diag_error = { fg = "#fb4934", bg = "#282828" },
    diag_warn = { fg = "#fabd2f", bg = "#282828" },
    diag_info = { fg = "#83a598", bg = "#282828" },
    main = { fg = "#ebdbb2", bg = "#282828" },
    filetype = { fg = "#d3869b", bg = "#282828" },
    encoding = { fg = "#8ec07c", bg = "#282828" },
  },
  nord = {
    normal = { fg = "#2E3440", bg = "#88C0D0" },
    insert = { fg = "#2E3440", bg = "#A3BE8C" },
    visual = { fg = "#2E3440", bg = "#B48EAD" },
    replace = { fg = "#2E3440", bg = "#BF616A" },
    command = { fg = "#2E3440", bg = "#EBCB8B" },
    terminal = { fg = "#2E3440", bg = "#8FBCBB" },
    inactive = { fg = "#4C566A", bg = "#3B4252" },
    git = { fg = "#A3BE8C", bg = "#2E3440" },
    diag_error = { fg = "#BF616A", bg = "#2E3440" },
    diag_warn = { fg = "#EBCB8B", bg = "#2E3440" },
    diag_info = { fg = "#88C0D0", bg = "#2E3440" },
    main = { fg = "#D8DEE9", bg = "#2E3440" },
    filetype = { fg = "#B48EAD", bg = "#2E3440" },
    encoding = { fg = "#8FBCBB", bg = "#2E3440" },
  },
}

local colors = themes[theme_current] or themes.gruvbox

-- ========================
-- Highlights
-- ========================
for name, col in pairs(colors) do
  local group = "StatusLine" .. name:gsub("^%l", string.upper):gsub("_", "")
  vim.cmd(string.format("highlight! %s guifg=%s guibg=%s gui=bold", group, col.fg, col.bg))
end

-- ========================
-- Mode mapping
-- ========================
local mode_map = {
  n = { name = "NORMAL", hl = "Normal" },
  i = { name = "INSERT", hl = "Insert" },
  v = { name = "VISUAL", hl = "Visual" },
  V = { name = "V-LINE", hl = "Visual" },
  [""] = { name = "V-BLOCK", hl = "Visual" },
  R = { name = "REPLACE", hl = "Replace" },
  c = { name = "COMMAND", hl = "Command" },
  t = { name = "TERMINAL", hl = "Terminal" },
  s = { name = "SELECT", hl = "Visual" },
  S = { name = "S-LINE", hl = "Visual" },
  [""] = { name = "S-BLOCK", hl = "Visual" },
  ["r"] = { name = "PROMPT", hl = "Replace" },
  ["!"] = { name = "SHELL", hl = "Command" },
}

local function mode_display()
  local m = fn.mode()
  local mode_info = mode_map[m] or { name = m, hl = "Normal" }
  return mode_info.name, "StatusLine" .. mode_info.hl
end

-- ========================
-- Async Git info (cached with TTL)
-- ========================
local git_cache = {}
local GIT_CACHE_TTL = 5000 -- 5 seconds

local function git_info()
  local cwd = fn.getcwd()
  local cache = git_cache[cwd]

  -- Return cached value if still valid
  if cache and (uv.now() - cache.time) < GIT_CACHE_TTL then
    return cache.value
  end

  if fn.executable "git" == 0 then
    git_cache[cwd] = { value = "", time = uv.now() }
    return ""
  end

  -- Return old cached value while fetching new one
  local old_value = cache and cache.value or ""

  vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { cwd = cwd }, function(res)
    if res.code ~= 0 then
      git_cache[cwd] = { value = "", time = uv.now() }
      return
    end

    local branch = vim.trim(res.stdout)
    vim.system({ "git", "status", "--porcelain" }, { cwd = cwd }, function(st)
      local stats = { added = 0, modified = 0, deleted = 0 }

      for line in st.stdout:gmatch "[^\r\n]+" do
        local status = line:sub(1, 2)
        if status:match "^[AM]" then
          stats.added = stats.added + 1
        end
        if status:match "^.M" then
          stats.modified = stats.modified + 1
        end
        if status:match "^.D" then
          stats.deleted = stats.deleted + 1
        end
      end

      local result = string.format(" %s", branch)
      if stats.added > 0 or stats.modified > 0 or stats.deleted > 0 then
        result = result .. string.format(" +%d ~%d -%d", stats.added, stats.modified, stats.deleted)
      end

      git_cache[cwd] = { value = result, time = uv.now() }
      vim.schedule(vim.cmd.redrawstatus)
    end)
  end)

  return old_value
end

-- ========================
-- Diagnostics with icons
-- ========================
local diag_icons = {
  [vim.diagnostic.severity.ERROR] = "E",
  [vim.diagnostic.severity.WARN] = "W",
  [vim.diagnostic.severity.INFO] = "I",
  [vim.diagnostic.severity.HINT] = "H",
}

local function diagnostics()
  local diags = vim.diagnostic.count(0)
  local parts = {}

  for severity, icon in pairs(diag_icons) do
    local count = diags[severity] or 0
    if count > 0 then
      local hl_name = severity == vim.diagnostic.severity.ERROR and "StatusLineDiagerror"
        or severity == vim.diagnostic.severity.WARN and "StatusLineDiagwarn"
        or "StatusLineDiaginfo"
      table.insert(parts, string.format("%%#%s#%s%d", hl_name, icon, count))
    end
  end

  return #parts > 0 and (" " .. table.concat(parts, " ") .. " ") or ""
end

-- ========================
-- File info with icon
-- ========================
local function file_info()
  local name = fn.expand "%:t"
  if name == "" then
    name = "[No Name]"
  end

  local modified = vim.bo.modified and "[+]" or ""
  local readonly = vim.bo.readonly and " " or ""

  return string.format(" %s%s%s ", name, modified, readonly)
end

-- ========================
-- File type
-- ========================
local function filetype()
  local ft = vim.bo.filetype
  return ft ~= "" and (" " .. ft .. " ") or ""
end

-- ========================
-- File encoding and format
-- ========================
local function encoding()
  local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
  local format = vim.bo.fileformat
  return string.format(" %s[%s] ", enc:upper(), format)
end

-- ========================
-- Cursor position with percentage
-- ========================
local function position()
  local line = fn.line "."
  local col = fn.col "."
  local total = fn.line "$"
  local percent = math.floor((line / total) * 100)
  return string.format(" %d:%d %d%%%% ", line, col, percent)
end

-- ========================
-- LSP status
-- ========================
local function lsp_status()
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if #clients == 0 then
    return ""
  end

  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end

  return string.format(" LSP[%s] ", table.concat(names, ","))
end

-- ========================
-- Statusline builder
-- ========================
function _G.status_line()
  local mode, mode_hl = mode_display()
  local git = git_info()
  local diag = diagnostics()
  local file = file_info()
  local ft = filetype()
  local enc = encoding()
  local pos = position()
  local lsp = lsp_status()

  return table.concat {
    "%#" .. mode_hl .. "# " .. mode .. " ",
    "%#StatusLineGit#" .. git,
    "%#StatusLineMain#" .. file,
    diag,
    lsp,
    "%=%#StatusLineFiletype#" .. ft,
    "%#StatusLineEncoding#" .. enc,
    "%#StatusLineMain#" .. pos,
  }
end

function _G.status_line_inactive()
  local file = fn.expand "%:t"
  if file == "" then
    file = "[No Name]"
  end
  return "%#StatusLineInactive# " .. file .. " %="
end

-- ========================
-- Apply and Auto-refresh
-- ========================
vim.o.laststatus = 3 -- Global statusline
vim.o.statusline = "%!v:lua.status_line()"

api.nvim_create_autocmd({ "ColorScheme", "WinEnter", "BufEnter" }, {
  callback = function()
    vim.wo.statusline = "%!v:lua.status_line()"
  end,
})

api.nvim_create_autocmd({ "WinLeave" }, {
  callback = function()
    vim.wo.statusline = "%!v:lua.status_line_inactive()"
  end,
})

-- Periodic git refresh
local timer = uv.new_timer()
timer:start(
  5000,
  5000,
  vim.schedule_wrap(function()
    git_cache = {} -- Clear cache periodically
    vim.cmd.redrawstatus()
  end)
)

-- Clear git cache on file write
api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    git_cache = {}
    vim.cmd.redrawstatus()
  end,
})
