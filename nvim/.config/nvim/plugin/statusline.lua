-- ========================
-- THEME-AWARE STATUSLINE (Async Git + Diagnostics)
-- ========================
local api, fn, uv = vim.api, vim.fn, vim.loop or vim.uv

-- ========================
-- Theme selection
-- ========================
local preferd_theme = "calamity"

-- ========================
-- Theme color definitions (Calamity)
-- ========================
local themes = {
  calamity = {
    -- Background: #0f0f0f (Deep Void)
    -- Foreground/Text: #f9e5c7 (Auric Silk)

    normal = { fg = "#0f0f0f", bg = "#73f973" }, -- Sulphurous Green
    insert = { fg = "#0f0f0f", bg = "#3ec1d3" }, -- Abyss Teal
    visual = { fg = "#0f0f0f", bg = "#b45ef7" }, -- Cosmic Purple
    replace = { fg = "#0f0f0f", bg = "#ff4646" }, -- Brimstone Red
    command = { fg = "#0f0f0f", bg = "#df9d1b" }, -- Auric Gold
    terminal = { fg = "#0f0f0f", bg = "#ffa500" }, -- Yharon Orange
    inactive = { fg = "#4c1111", bg = "#1a1a1a" }, -- Dried Blood on Dark Charcoal

    git = { fg = "#73f973", bg = "#0f0f0f" }, -- Sulphurous Green
    diag_error = { fg = "#ff003c", bg = "#0f0f0f" }, -- Profaned Flame
    diag_warn = { fg = "#df9d1b", bg = "#0f0f0f" }, -- Auric Gold
    diag_info = { fg = "#3ec1d3", bg = "#0f0f0f" }, -- Abyss Teal

    main = { fg = "#f9e5c7", bg = "#2d2d2d" }, -- Auric Silk on Light Charcoal
    filetype = { fg = "#b45ef7", bg = "#0f0f0f" }, -- Cosmic Purple
    encoding = { fg = "#e0e0e0", bg = "#0f0f0f" }, -- Exo Silver
  },
}

local theme_current = preferd_theme

-- Conditional styling based on Neovide
local gui_attr = (vim.g.neovide or vim.g.neovide_version) and "gui=NONE cterm=NONE" or "gui=bold"

-- Function to apply highlights (DRY principle)
local function apply_highlights()
  local colors = themes[theme_current]
  for name, col in pairs(colors) do
    local group = "StatusLine" .. name:gsub("^%l", string.upper):gsub("_", "")
    vim.cmd(string.format("highlight! %s guifg=%s guibg=%s %s", group, col.fg, col.bg, gui_attr))
  end
end

local colors = themes[theme_current]

-- ========================
-- Initial highlights
-- ========================
apply_highlights()

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
