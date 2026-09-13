-- nvim/plugin/indent-lines.lua
-- ============================================================================
-- USER CONFIGURATION - Edit these values to customize the plugin
-- ============================================================================
local config = {
  enabled = true, -- Enable/disable the plugin
  char = "▎", -- Character for indent lines
  show_current_context = true, -- Highlight the current code block scope
  debounce_ms = 100, -- Delay before redrawing
  max_lines = 10000, -- Don't draw indent lines for larger files
}

-- Add custom excluded filetypes here
local custom_excluded_filetypes = {
  -- "markdown",
  -- "text",
}

-- Add custom excluded buftypes here
local custom_excluded_buftypes = {
  -- "help",
}
-- ============================================================================
-- END OF USER CONFIGURATION
-- ============================================================================

-- ============================================================================
-- Theme palette (theme-aware)
-- ============================================================================
-- theme.lua publishes its resolved palette on _G.__colorscheme_palette. We
-- build our indent-line highlight groups from that, so guide colors stay in
-- sync when the palette is tweaked or the colorscheme is swapped.
--
-- Source theme.lua *before* this file so the export exists on startup. If it
-- doesn't, the fallback below (identical to theme.lua's default gruvbox
-- palette) is used, and the ColorScheme autocmd below picks up the real one.
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

-- Successive indent levels cycle through these palette keys. The current
-- scope's guide uses a dedicated accent so it stands out from the cycle.
local INDENT_CYCLE = { "red", "green", "yellow", "blue", "purple", "orange", "fg1" }
local CONTEXT_KEY = "yellow"

local function apply_highlights()
  local c = palette()
  for i, key in ipairs(INDENT_CYCLE) do
    vim.api.nvim_set_hl(0, "IndentLine" .. i, { fg = c[key] })
  end
  vim.api.nvim_set_hl(0, "IndentLineContext", { fg = c[CONTEXT_KEY] })
end

-- ============================================================================
-- Exclusion lists
-- ============================================================================
local excluded_filetypes = {
  "help",
  "lazy",
  "mason",
  "dashboard",
  "NvimTree",
  "neo-tree",
  "Trouble",
  "trouble",
  "notify",
  "toggleterm",
  "alpha",
  "startify",
  "TelescopePrompt",
  "TelescopeResults",
  "lspinfo",
  "checkhealth",
  "man",
  "qf",
  "query",
  "aerial",
  "packer",
  "noice",
  "",
}

for _, ft in ipairs(custom_excluded_filetypes) do
  table.insert(excluded_filetypes, ft)
end

local excluded_buftypes = {
  "terminal",
  "nofile",
  "quickfix",
  "prompt",
  "acwrite",
}

for _, bt in ipairs(custom_excluded_buftypes) do
  table.insert(excluded_buftypes, bt)
end

-- Cache for exclusion checks
local exclusion_cache = {}

-- Debounce timers
local timers = {}

-- Namespace for extmarks
local ns = vim.api.nvim_create_namespace "indent_lines"

-- Context cache
local context_cache = {
  buf = -1,
  line = -1,
  start = nil,
  end_line = nil,
  indent = nil,
}

-- Validate configuration
local function validate_config()
  if config.debounce_ms < 0 then
    config.debounce_ms = 0
  end
  if config.max_lines < 100 then
    config.max_lines = 100
  end
  if type(config.char) ~= "string" or config.char == "" then
    config.char = "▎"
  end
end

-- Check if buffer should be excluded.
local function should_exclude(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return true
  end

  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype

  local cache_key = buf .. "\0" .. ft .. "\0" .. bt
  if exclusion_cache[cache_key] ~= nil then
    return exclusion_cache[cache_key]
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count > config.max_lines then
    exclusion_cache[cache_key] = true
    return true
  end

  for _, excluded_ft in ipairs(excluded_filetypes) do
    if ft == excluded_ft then
      exclusion_cache[cache_key] = true
      return true
    end
  end

  for _, excluded_bt in ipairs(excluded_buftypes) do
    if bt == excluded_bt then
      exclusion_cache[cache_key] = true
      return true
    end
  end

  exclusion_cache[cache_key] = false
  return false
end

-- Get the context range (start and end line of current code block)
local function get_context_range(buf, cursor_line)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local shiftwidth = vim.bo[buf].shiftwidth
  if shiftwidth == 0 then
    shiftwidth = vim.bo[buf].tabstop
  end
  if shiftwidth == 0 then
    shiftwidth = 2
  end

  local cursor_indent = 0
  if cursor_line <= #lines then
    local line = lines[cursor_line]
    if not line:match "^%s*$" then
      cursor_indent = line:match("^%s*"):len()
    else
      for i = cursor_line - 1, 1, -1 do
        if not lines[i]:match "^%s*$" then
          cursor_indent = lines[i]:match("^%s*"):len()
          break
        end
      end
    end
  end

  local scope_indent = cursor_indent
  local start_line = cursor_line
  local is_definition = false

  for i = cursor_line + 1, math.min(cursor_line + 10, #lines) do
    local line = lines[i]
    if not line:match "^%s*$" then
      local next_indent = line:match("^%s*"):len()
      if next_indent > cursor_indent then
        scope_indent = next_indent
        is_definition = true
      end
      break
    end
  end

  if cursor_indent == 0 and scope_indent == 0 then
    return nil, nil, nil
  end

  if not is_definition then
    if cursor_indent > 0 then
      scope_indent = cursor_indent
      for i = cursor_line - 1, 1, -1 do
        local line = lines[i]
        if not line:match "^%s*$" then
          local indent = line:match("^%s*"):len()
          if indent < cursor_indent then
            start_line = i
            break
          end
        end
      end
    else
      return nil, nil, nil
    end
  end

  local end_line = #lines
  local target_indent = is_definition and cursor_indent or (cursor_indent - shiftwidth)

  for i = cursor_line + 1, #lines do
    local line = lines[i]
    if not line:match "^%s*$" then
      local indent = line:match("^%s*"):len()
      if indent <= target_indent then
        end_line = i - 1
        break
      end
    end
  end

  return start_line, end_line, scope_indent
end

local function get_context_range_cached(buf, cursor_line)
  if context_cache.buf == buf and context_cache.line == cursor_line then
    return context_cache.start, context_cache.end_line, context_cache.indent
  end

  local start, end_line, indent = get_context_range(buf, cursor_line)
  context_cache = {
    buf = buf,
    line = cursor_line,
    start = start,
    end_line = end_line,
    indent = indent,
  }
  return start, end_line, indent
end

-- Draw indent guides
local function draw_indent_lines(buf)
  if not config.enabled or should_exclude(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local shiftwidth = vim.bo[buf].shiftwidth
  if shiftwidth == 0 then
    shiftwidth = vim.bo[buf].tabstop
  end
  if shiftwidth == 0 then
    shiftwidth = 2
  end

  local palette_size = #INDENT_CYCLE

  local cursor_line = nil
  local context_start, context_end, context_indent

  if config.show_current_context then
    local wins = vim.fn.win_findbuf(buf)
    if #wins > 0 then
      cursor_line = vim.api.nvim_win_get_cursor(wins[1])[1]
      context_start, context_end, context_indent = get_context_range_cached(buf, cursor_line)
    end
  end

  local prev_indent = 0

  for lnum, line in ipairs(lines) do
    local indent
    local is_blank = line:match "^%s*$"

    if is_blank then
      indent = prev_indent
      if indent == 0 then
        for future_lnum = lnum + 1, math.min(lnum + 5, #lines) do
          local future_line = lines[future_lnum]
          if not future_line:match "^%s*$" then
            indent = future_line:match("^%s*"):len()
            break
          end
        end
      end
    else
      indent = line:match("^%s*"):len()
      prev_indent = indent
    end

    for col = 0, indent - 1, shiftwidth do
      local level = (col / shiftwidth) % palette_size + 1
      local hl_group = "IndentLine" .. level

      if config.show_current_context and cursor_line and context_start and context_end and context_indent then
        if lnum >= context_start and lnum <= context_end then
          local context_col = context_indent - shiftwidth
          if context_col >= 0 and col == context_col then
            hl_group = "IndentLineContext"
          end
        end
      end

      if is_blank then
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
          virt_text = { { config.char, hl_group } },
          virt_text_win_col = col,
          priority = 1,
        })
      else
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, {
          virt_text = { { config.char, hl_group } },
          virt_text_pos = "overlay",
          priority = 1,
        })
      end
    end
  end
end

-- Only redraw buffers that are actually loaded and currently displayed.
local function redraw_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not should_exclude(buf) then
      draw_indent_lines(buf)
    end
  end
end

-- Apply initial highlights
apply_highlights()

-- If theme.lua hasn't run yet, re-apply once the palette becomes available.
if not _G.__colorscheme_palette then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.schedule(function()
        apply_highlights()
        redraw_all_buffers()
      end)
    end,
  })
end

-- Clear per-buffer caches on buffer delete
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(ev)
    local prefix = ev.buf .. "\0"
    for key in pairs(exclusion_cache) do
      if key:sub(1, #prefix) == prefix then
        exclusion_cache[key] = nil
      end
    end
    if timers[ev.buf] then
      timers[ev.buf]:stop()
      timers[ev.buf] = nil
    end
    if context_cache.buf == ev.buf then
      context_cache = { buf = -1, line = -1, start = nil, end_line = nil, indent = nil }
    end
  end,
})

-- Debounced draw function
local function draw_debounced(buf)
  if timers[buf] then
    timers[buf]:stop()
  end
  timers[buf] = vim.defer_fn(function()
    draw_indent_lines(buf)
    timers[buf] = nil
  end, config.debounce_ms)
end

-- Auto-refresh on buffer changes
local group = vim.api.nvim_create_augroup("IndentLines", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = group,
  callback = function(ev)
    if ev.event == "FileType" then
      local prefix = ev.buf .. "\0"
      for key in pairs(exclusion_cache) do
        if key:sub(1, #prefix) == prefix then
          exclusion_cache[key] = nil
        end
      end
    end
    if should_exclude(ev.buf) then
      vim.api.nvim_buf_clear_namespace(ev.buf, ns, 0, -1)
    else
      draw_indent_lines(ev.buf)
    end
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    draw_debounced(ev.buf)
  end,
})

if config.show_current_context then
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      if should_exclude(ev.buf) then
        return
      end
      local wins = vim.fn.win_findbuf(ev.buf)
      if #wins == 0 then
        return
      end
      local cursor_line = vim.api.nvim_win_get_cursor(wins[1])[1]
      local new_start, new_end, new_indent = get_context_range(ev.buf, cursor_line)
      if new_start ~= context_cache.start or new_end ~= context_cache.end_line or new_indent ~= context_cache.indent then
        draw_debounced(ev.buf)
      end
    end,
  })
end

-- Refresh highlights (and redraw) when the colorscheme/palette changes.
-- Scheduled so theme.lua's own ColorScheme handler (which regenerates
-- _G.__colorscheme_palette) runs first, regardless of sourcing order.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    vim.schedule(function()
      apply_highlights()
      redraw_all_buffers()
    end)
  end,
})

-- Command to toggle indent lines
vim.api.nvim_create_user_command("IndentLinesToggle", function()
  config.enabled = not config.enabled
  if config.enabled then
    local buf = vim.api.nvim_get_current_buf()
    draw_indent_lines(buf)
    vim.notify("Indent lines enabled", vim.log.levels.INFO)
  else
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
    vim.notify("Indent lines disabled", vim.log.levels.INFO)
  end
end, {})

-- Command to toggle context highlighting
vim.api.nvim_create_user_command("IndentLinesToggleContext", function()
  config.show_current_context = not config.show_current_context
  local buf = vim.api.nvim_get_current_buf()
  draw_indent_lines(buf)
  local status = config.show_current_context and "enabled" or "disabled"
  vim.notify("Context highlighting " .. status, vim.log.levels.INFO)
end, {})

-- Command to reload configuration and re-apply palette
vim.api.nvim_create_user_command("IndentLinesReload", function()
  validate_config()
  apply_highlights()
  redraw_all_buffers()
  vim.notify("Indent lines reloaded", vim.log.levels.INFO)
end, {})

-- Expose config for runtime access
_G.IndentLinesConfig = config

-- Validate config on startup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(validate_config, 50)
  end,
})
