-- ========================
-- THEME-AWARE STATUSLINE (Async Git + Diagnostics)
-- ========================

local api, fn = vim.api, vim.fn

-- ========================
-- Theme reading
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
  return theme
end

local theme_current = (read_theme(theme_file) or "gruvbox"):lower()

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
    inactive = { fg = "#ebdbb2", bg = "#3c3836" },
    git = { fg = "#b8bb26", bg = "#282828" },
    diag = { fg = "#fabd2f", bg = "#282828" },
    main = { fg = "#ebdbb2", bg = "#282828" },
  },
  nord = {
    normal = { fg = "#D8DEE9", bg = "#2E3440" },
    insert = { fg = "#D8DEE9", bg = "#5E81AC" },
    visual = { fg = "#D8DEE9", bg = "#B48EAD" },
    replace = { fg = "#D8DEE9", bg = "#BF616A" },
    command = { fg = "#D8DEE9", bg = "#D08770" },
    inactive = { fg = "#D8DEE9", bg = "#3B4252" },
    git = { fg = "#EBCB8B", bg = "#2E3440" },
    diag = { fg = "#EBCB8B", bg = "#2E3440" },
    main = { fg = "#D8DEE9", bg = "#2E3440" },
  },
}

local colors = themes[theme_current] or themes.gruvbox

-- ========================
-- Highlights
-- ========================
for name, col in pairs(colors) do
  local group = "StatusLine" .. name:gsub("^%l", string.upper)
  vim.cmd(string.format("highlight! %s guifg=%s guibg=%s gui=bold", group, col.fg, col.bg))
end

-- ========================
-- Mode mapping
-- ========================
local mode_map = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "V-LINE",
  [""] = "V-BLOCK",
  R = "REPLACE",
  c = "COMMAND",
  t = "TERMINAL",
}

local function mode_display()
  local m = fn.mode()
  return mode_map[m] or m
end

-- ========================
-- Async Git info (cached)
-- ========================
local git_cache = {}

local function git_info()
  local cwd = fn.getcwd()
  if git_cache[cwd] then
    return git_cache[cwd]
  end
  if fn.executable "git" == 0 then
    return ""
  end

  local result = ""
  vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { cwd = cwd }, function(res)
    if res.code ~= 0 then
      git_cache[cwd] = ""
      return
    end
    local branch = vim.trim(res.stdout)
    vim.system({ "git", "status", "--porcelain" }, { cwd = cwd }, function(st)
      local dirty = (st.stdout ~= "") and "+" or ""
      result = branch .. dirty
      git_cache[cwd] = result
      vim.schedule(vim.cmd.redrawstatus)
    end)
  end)
  return git_cache[cwd] or ""
end

-- ========================
-- Diagnostics
-- ========================
local function diagnostics()
  local diags = vim.diagnostic.count(0)
  local err = diags[vim.diagnostic.severity.ERROR] or 0
  local warn = diags[vim.diagnostic.severity.WARN] or 0
  if err == 0 and warn == 0 then
    return ""
  end
  return string.format("E%d W%d ", err, warn)
end

-- ========================
-- File info
-- ========================
local function file_info()
  local name = fn.expand "%:t"
  if name == "" then
    name = "[No Name]"
  end
  if vim.bo.modified then
    name = name .. " +"
  end
  return name
end

-- ========================
-- Cursor position
-- ========================
local function position()
  local line = fn.line "."
  local col = fn.col "."
  local total = fn.line "$"
  return string.format("%d:%d/%d", line, col, total)
end

-- ========================
-- Statusline builder
-- ========================
function _G.status_line()
  local mode = mode_display()
  local mode_group = "StatusLine" .. (mode:lower():gsub("^%l", string.upper))
  local diag = diagnostics()
  local git = git_info()
  local file = file_info()
  local pos = position()

  return table.concat {
    "%#" .. mode_group .. "# " .. mode .. " ",
    "%#StatusLineGit# " .. git .. " ",
    "%#StatusLineMain# " .. file .. " ",
    "%#StatusLineDiag# " .. diag .. " ",
    "%=%#StatusLineMain# " .. pos .. " ",
  }
end

-- ========================
-- Apply and Auto-refresh
-- ========================
vim.o.laststatus = 2
vim.o.statusline = "%!v:lua.status_line()"

api.nvim_create_autocmd({ "ColorScheme", "WinEnter", "BufEnter" }, {
  callback = function()
    vim.o.statusline = "%!v:lua.status_line()"
  end,
})
