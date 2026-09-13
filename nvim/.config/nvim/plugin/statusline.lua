-- ========================
-- THEME-AWARE STATUSLINE (Async Git + Diagnostics)
-- ========================
local api, fn, uv = vim.api, vim.fn, vim.uv or vim.loop

-- ========================
-- Theme colors
-- ========================
-- The active colorscheme (theme.lua) publishes its resolved palette on
-- _G.__colorscheme_palette. We build our statusline highlight groups from
-- that, so the statusline stays in sync when the palette is tweaked or the
-- theme is swapped.
--
-- Source theme.lua *before* this file so the export exists on startup.
-- If it doesn't, the fallback below (identical to the default gruvbox
-- palette) is used, and any later ColorScheme event picks up the real one.
local fallback_palette = {
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
  return _G.__colorscheme_palette or fallback_palette
end

-- Bold mode labels; Neovide looks better with a flatter style.
local bold_labels = not (vim.g.neovide or vim.g.neovide_version)

-- ========================
-- Highlight groups
-- ========================
-- Filetype icon colors are cached per-filetype against the current palette's
-- background, so the cache is cleared whenever the palette changes.
local ft_hl_cache = {}

local function apply_highlights()
  local c = palette()

  local groups = {
    -- Mode segments: dark text on the mode's accent color.
    StatusLineNormal = { fg = c.bg0, bg = c.green, bold = bold_labels },
    StatusLineInsert = { fg = c.bg0, bg = c.blue, bold = bold_labels },
    StatusLineVisual = { fg = c.bg0, bg = c.purple, bold = bold_labels },
    StatusLineReplace = { fg = c.bg0, bg = c.red, bold = bold_labels },
    StatusLineCommand = { fg = c.bg0, bg = c.yellow, bold = bold_labels },
    StatusLineTerminal = { fg = c.bg0, bg = c.orange, bold = bold_labels },
    StatusLineInactive = { fg = c.bg4, bg = c.bg1, bold = bold_labels },

    -- Content segments: accent text on the statusline's dark background.
    StatusLineGit = { fg = c.green, bg = c.bg0, bold = bold_labels },
    StatusLineDiagerror = { fg = c.red, bg = c.bg0, bold = bold_labels },
    StatusLineDiagwarn = { fg = c.yellow, bg = c.bg0, bold = bold_labels },
    StatusLineDiaginfo = { fg = c.blue, bg = c.bg0, bold = bold_labels },

    StatusLineMain = { fg = c.fg1, bg = c.bg2, bold = bold_labels },
    StatusLineFiletype = { fg = c.purple, bg = c.bg0, bold = bold_labels },
    StatusLineEncoding = { fg = c.fg3, bg = c.bg0, bold = bold_labels },
  }

  for group, hl in pairs(groups) do
    api.nvim_set_hl(0, group, hl)
  end

  ft_hl_cache = {}
end

apply_highlights()

-- ========================
-- Mode mapping
-- ========================
local mode_map = {
  n = { name = "NORMAL", hl = "Normal" },
  i = { name = "INSERT", hl = "Insert" },
  v = { name = "VISUAL", hl = "Visual" },
  V = { name = "V-LINE", hl = "Visual" },
  ["\22"] = { name = "V-BLOCK", hl = "Visual" }, -- CTRL-V
  R = { name = "REPLACE", hl = "Replace" },
  c = { name = "COMMAND", hl = "Command" },
  t = { name = "TERMINAL", hl = "Terminal" },
  s = { name = "SELECT", hl = "Visual" },
  S = { name = "S-LINE", hl = "Visual" },
  ["\19"] = { name = "S-BLOCK", hl = "Visual" }, -- CTRL-S
  ["r"] = { name = "PROMPT", hl = "Replace" },
  ["!"] = { name = "SHELL", hl = "Command" },
}

local function mode_display()
  local m = fn.mode()
  local mode_info = mode_map[m] or { name = m, hl = "Normal" }
  return mode_info.name, "StatusLine" .. mode_info.hl
end

-- ========================
-- Async Git info (cached with TTL, single-flight per cwd)
-- ========================
local git_cache = {}
local GIT_CACHE_TTL = 5000 -- 5 seconds

local function git_info()
  local cwd = fn.getcwd()
  local cache = git_cache[cwd]

  if cache and (uv.now() - cache.time) < GIT_CACHE_TTL then
    return cache.value
  end

  if cache and cache.fetching then
    return cache.value or ""
  end

  if fn.executable "git" == 0 then
    git_cache[cwd] = { value = "", time = uv.now() }
    return ""
  end

  local old_value = cache and cache.value or ""
  git_cache[cwd] = { value = old_value, time = cache and cache.time or 0, fetching = true }

  vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { cwd = cwd }, function(res)
    if res.code ~= 0 then
      git_cache[cwd] = { value = "", time = uv.now(), fetching = false }
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
        result = result .. string.format(" +%d ~%d -%d ", stats.added, stats.modified, stats.deleted)
      end

      git_cache[cwd] = { value = result, time = uv.now(), fetching = false }
      vim.schedule(vim.cmd.redrawstatus)
    end)
  end)

  return old_value
end

-- ========================
-- Diagnostics with icons (fixed, ordered iteration)
-- ========================
local diag_order = {
  vim.diagnostic.severity.ERROR,
  vim.diagnostic.severity.WARN,
  vim.diagnostic.severity.INFO,
  vim.diagnostic.severity.HINT,
}

local diag_icons = {
  [vim.diagnostic.severity.ERROR] = "󰅚 ",
  [vim.diagnostic.severity.WARN] = "󰀪 ",
  [vim.diagnostic.severity.INFO] = " ",
  [vim.diagnostic.severity.HINT] = " ",
}

local diag_hl = {
  [vim.diagnostic.severity.ERROR] = "StatusLineDiagerror",
  [vim.diagnostic.severity.WARN] = "StatusLineDiagwarn",
  [vim.diagnostic.severity.INFO] = "StatusLineDiaginfo",
  [vim.diagnostic.severity.HINT] = "StatusLineDiaginfo",
}

local function diagnostics()
  local diags = vim.diagnostic.count(0)
  local parts = {}

  for _, severity in ipairs(diag_order) do
    local count = diags[severity] or 0
    if count > 0 then
      table.insert(parts, string.format("%%#%s# %s%d", diag_hl[severity], diag_icons[severity], count))
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
-- File type (icon highlight cached per-filetype)
-- ========================
local function filetype()
  local ft = vim.bo.filetype
  if ft == "" then
    return ""
  end

  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return string.format(" %s ", ft)
  end

  if not ft_hl_cache[ft] then
    local icon, color = devicons.get_icon_color_by_filetype(ft, { default = true })
    api.nvim_set_hl(0, "StatusLineFtIcon", { fg = color, bg = palette().bg0 })
    ft_hl_cache[ft] = icon
  end

  return string.format(" %%#StatusLineFtIcon#%s%%#StatusLineFiletype# %s ", ft_hl_cache[ft], ft)
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
-- Apply and Auto-refresh (guarded against re-sourcing)
-- ========================
local group = api.nvim_create_augroup("StatuslineCustom", { clear = true })

api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = group,
  callback = function()
    vim.wo.statusline = "%!v:lua.status_line()"
  end,
})

api.nvim_create_autocmd({ "WinLeave" }, {
  group = group,
  callback = function()
    vim.wo.statusline = "%!v:lua.status_line_inactive()"
  end,
})

-- Refresh highlights and window option when the colorscheme changes.
-- Scheduled so the colorscheme's own ColorScheme handler (which regenerates
-- _G.__colorscheme_palette) runs first, regardless of sourcing order.
api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    vim.schedule(function()
      apply_highlights()
      vim.wo.statusline = "%!v:lua.status_line()"
    end)
  end,
})

-- Redraw promptly on LSP/diagnostic changes rather than waiting on the timer
api.nvim_create_autocmd({ "LspAttach", "LspDetach", "DiagnosticChanged" }, {
  group = group,
  callback = function()
    vim.cmd.redrawstatus()
  end,
})

-- Clear git cache on file write
api.nvim_create_autocmd({ "BufWritePost" }, {
  group = group,
  callback = function()
    git_cache = {}
    vim.cmd.redrawstatus()
  end,
})

-- Periodic git refresh (single timer, survives re-sourcing this file)
if not _G.__statusline_git_timer then
  _G.__statusline_git_timer = uv.new_timer()
  _G.__statusline_git_timer:start(
    5000,
    5000,
    vim.schedule_wrap(function()
      git_cache = {}
      vim.cmd.redrawstatus()
    end)
  )
end

-- Apply to the current window immediately (autocmds handle future ones).
vim.wo.statusline = "%!v:lua.status_line()"
