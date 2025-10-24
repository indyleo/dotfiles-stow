-- Ensure laststatus is always shown
vim.o.laststatus = 2

-- Fetch current theme from environment
local theme_current = os.getenv "THEME_CURRENT" or "gruvbox"

-- Define colors for themes
local themes = {
  ["gruvbox"] = {
    normal = { fg = "#ebdbb2", bg = "#458588" },
    insert = { fg = "#ebdbb2", bg = "#b8bb26" },
    visual = { fg = "#ebdbb2", bg = "#d3869b" },
    replace = { fg = "#ebdbb2", bg = "#fb4934" },
    command = { fg = "#ebdbb2", bg = "#fe8019" },
    inactive = { fg = "#ebdbb2", bg = "#3c3836" },
    git_dirty = { fg = "#b8bb26", bg = "#282828" },
    update = { fg = "#fabd2f", bg = "#282828" },
    main = { fg = "#ebdbb2", bg = "#282828" },
  },
  ["nord"] = {
    normal = { fg = "#D8DEE9", bg = "#2E3440" },
    insert = { fg = "#D8DEE9", bg = "#5E81AC" },
    visual = { fg = "#D8DEE9", bg = "#B48EAD" },
    replace = { fg = "#D8DEE9", bg = "#BF616A" },
    command = { fg = "#D8DEE9", bg = "#D08770" },
    inactive = { fg = "#D8DEE9", bg = "#3B4252" },
    git_dirty = { fg = "#EBCB8B", bg = "#2E3440" },
    update = { fg = "#EBCB8B", bg = "#2E3440" },
    main = { fg = "#D8DEE9", bg = "#2E3440" },
  },
}

-- Pick current theme or fallback
local colors = themes[theme_current:lower()] or themes["default"]

-- Create highlight groups dynamically
for name, col in pairs(colors) do
  vim.cmd(string.format("highlight StatusLine%s guifg=%s guibg=%s gui=bold", name:gsub("^%l", string.upper), col.fg, col.bg))
end

-- Git branch + dirty
local function git_info()
  local branch = ""
  local handle = io.popen "git rev-parse --abbrev-ref HEAD 2>/dev/null"
  if handle then
    branch = handle:read "*a" or ""
    handle:close()
    branch = branch:gsub("^%s*(.-)%s*$", "%1")
  end
  if branch == "" then
    return ""
  end

  local dirty = ""
  local handle2 = io.popen "git status --porcelain 2>/dev/null"
  if handle2 then
    dirty = handle2:read "*a" or ""
    handle2:close()
    dirty = (dirty ~= "") and "+" or ""
  end

  return branch .. dirty
end

-- Dummy update indicator
local function updates()
  local has_updates = false
  return has_updates and "⬆️" or ""
end

-- Mode colors mapping
local mode_colors = {
  n = "Normal",
  i = "Insert",
  v = "Visual",
  V = "Visual",
  ["\22"] = "Visual",
  R = "Replace",
  c = "Command",
  t = "Command",
}

-- Build statusline
function _G.status_line()
  local mode_info = vim.api.nvim_get_mode().mode or "n"
  local mode_group = mode_colors[mode_info] or "Inactive"
  local mode_display = mode_info:upper()

  -- Left: mode block (no separator)
  local left = string.format("%%#StatusLine%s# %s ", mode_group, mode_display)

  -- Middle: filename + modified + git + updates
  local filename = "%#StatusLineMain# %f%m "
  local git = git_info()
  if git ~= "" then
    git = "%#StatusLineGit_dirty# " .. git .. " "
  end
  local update_icon = "%#StatusLineUpdate#" .. updates() .. " "

  local middle = filename .. git .. update_icon

  -- Right-aligned info
  local right = "%=" .. " %l/%L:%c %p%% %{&filetype}"

  return left .. middle .. right
end

-- Apply statusline
vim.o.statusline = "%!v:lua.status_line()"

-- Optional: refresh statusline on window enter
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  callback = function()
    vim.o.statusline = "%!v:lua.status_line()"
  end,
})
