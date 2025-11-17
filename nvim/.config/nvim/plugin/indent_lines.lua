-- nvim/plugin/indent-lines.lua
-- ============================================================================
-- USER CONFIGURATION - Edit these values to customize the plugin
-- ============================================================================
local config = {
  enabled = true, -- Enable/disable the plugin
  char = "▎", -- Character for indent lines (try: "│", "▏", "▎", "▍")
  show_current_context = true, -- Highlight the current code block scope
  debounce_ms = 100, -- Delay before redrawing (lower = more responsive, higher = better performance)
  max_lines = 10000, -- Don't draw indent lines for files larger than this
}

-- Available themes: "gruvbox", "nord", "catppuccin", "tokyonight", "onedark"
-- Set your preferred theme here or it will be read from ~/.cache/theme file
local preferred_theme = "gruvbox" -- Change this to your preferred theme

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

-- Get cache directory for theme
local cache_home = os.getenv "XDG_CACHE_HOME" or os.getenv "HOME" .. "/.cache"
local theme_file = cache_home .. "/theme"

-- Read theme from file
local function read_theme(path)
  local f = io.open(path, "r")
  if f then
    local theme = f:read "*l"
    f:close()
    return theme
  end
  return nil
end

-- Theme colors with context color
local colors = {
  gruvbox = {
    normal = { "#fb4934", "#fabd2f", "#83a598", "#fe8019", "#b8bb26", "#d3869b", "#8ec07c" },
    context = "#928374",
  },
  nord = {
    normal = { "#BF616A", "#EBCB8B", "#81A1C1", "#D08770", "#A3BE8C", "#B48EAD", "#88C0D0" },
    context = "#4C566A",
  },
}

-- Current theme (mutable)
local theme_current = read_theme(theme_file) or preferred_theme

-- Filetypes to exclude
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

-- Add custom excluded filetypes
for _, ft in ipairs(custom_excluded_filetypes) do
  table.insert(excluded_filetypes, ft)
end

-- Buftypes to exclude
local excluded_buftypes = {
  "terminal",
  "nofile",
  "quickfix",
  "prompt",
  "acwrite",
}

-- Add custom excluded buftypes
for _, bt in ipairs(custom_excluded_buftypes) do
  table.insert(excluded_buftypes, bt)
end

-- Cache for exclusion checks
local exclusion_cache = {}

-- Debounce timer
local timers = {}

-- Theme change debounce timer
local theme_debounce_timer = nil

-- Namespace for extmarks
local ns = vim.api.nvim_create_namespace "indent_lines"

-- Context cache for performance
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
  if not colors[theme_current] then
    theme_current = preferred_theme
  end
  if type(config.char) ~= "string" or config.char == "" then
    config.char = "▎"
  end
end

-- Check if buffer should be excluded
local function should_exclude(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return true
  end

  -- Check cache first
  if exclusion_cache[buf] ~= nil then
    return exclusion_cache[buf]
  end

  -- Check if buffer is too large (performance)
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count > config.max_lines then
    exclusion_cache[buf] = true
    return true
  end

  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype

  -- Check filetype
  for _, excluded_ft in ipairs(excluded_filetypes) do
    if ft == excluded_ft then
      exclusion_cache[buf] = true
      return true
    end
  end

  -- Check buftype
  for _, excluded_bt in ipairs(excluded_buftypes) do
    if bt == excluded_bt then
      exclusion_cache[buf] = true
      return true
    end
  end

  exclusion_cache[buf] = false
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

  -- Get indent of cursor line
  local cursor_indent = 0
  if cursor_line <= #lines then
    local line = lines[cursor_line]
    if not line:match "^%s*$" then
      cursor_indent = line:match("^%s*"):len()
    else
      -- If cursor is on blank line, find nearest non-blank line
      for i = cursor_line - 1, 1, -1 do
        if not lines[i]:match "^%s*$" then
          cursor_indent = lines[i]:match("^%s*"):len()
          break
        end
      end
    end
  end

  -- Find the scope: look at the next non-blank line
  -- If it has MORE indent than cursor, we're on a definition line
  local scope_indent = cursor_indent
  local start_line = cursor_line
  local is_definition = false

  for i = cursor_line + 1, math.min(cursor_line + 10, #lines) do
    local line = lines[i]
    if not line:match "^%s*$" then
      local next_indent = line:match("^%s*"):len()
      if next_indent > cursor_indent then
        -- Next line is more indented, so cursor is on definition line
        -- Use the next line's indent as scope
        scope_indent = next_indent
        is_definition = true
      end
      break
    end
  end

  -- If cursor is at indent 0 and no inner scope found, no context to show
  if cursor_indent == 0 and scope_indent == 0 then
    return nil, nil, nil
  end

  -- If we're inside a block (not on definition), use cursor indent as scope
  if not is_definition then
    if cursor_indent > 0 then
      scope_indent = cursor_indent
      -- Find parent scope start
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
      -- At root level but not a definition, no context
      return nil, nil, nil
    end
  end

  -- Find end of scope
  local end_line = #lines
  local target_indent = is_definition and cursor_indent or (cursor_indent - shiftwidth)

  for i = cursor_line + 1, #lines do
    local line = lines[i]
    if not line:match "^%s*$" then
      local indent = line:match("^%s*"):len()
      -- End when we find a line with less or equal indent than target
      if indent <= target_indent then
        end_line = i - 1
        break
      end
    end
  end

  return start_line, end_line, scope_indent
end

-- Get context range with caching
local function get_context_range_cached(buf, cursor_line)
  if context_cache.buf == buf and context_cache.line and math.abs(context_cache.line - cursor_line) <= 1 then
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

  -- Get current theme colors
  local theme_colors = colors[theme_current] or colors.gruvbox
  local palette = theme_colors.normal

  -- Get current cursor position and context
  local cursor_line = nil
  local context_start, context_end, context_indent

  if config.show_current_context then
    local wins = vim.fn.win_findbuf(buf)
    if #wins > 0 then
      cursor_line = vim.api.nvim_win_get_cursor(wins[1])[1]
      context_start, context_end, context_indent = get_context_range_cached(buf, cursor_line)
    end
  end

  -- Track indent levels to continue through blank lines
  local prev_indent = 0

  for lnum, line in ipairs(lines) do
    local indent
    local is_blank = line:match "^%s*$"

    if is_blank then
      -- Look backwards for indent
      indent = prev_indent
      -- Also look forward to handle sections of blank lines better
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

    -- Draw each indent guide
    for col = 0, indent - 1, shiftwidth do
      local level = (col / shiftwidth) % #palette + 1
      local hl_group = "IndentLine" .. level

      -- Check if this indent level should be highlighted as context
      if config.show_current_context and cursor_line and context_start and context_end and context_indent then
        if lnum >= context_start and lnum <= context_end then
          -- Highlight the indent guide at one level before the context level
          -- (the indent guide that marks the scope we're inside)
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

-- Function to apply highlight groups
local function apply_highlights()
  local theme_colors = colors[theme_current] or colors.gruvbox
  local palette = theme_colors.normal
  local context_color = theme_colors.context

  -- Normal indent line highlights
  for i, color in ipairs(palette) do
    vim.api.nvim_set_hl(0, "IndentLine" .. i, { fg = color })
  end

  -- Single context indent line highlight
  vim.api.nvim_set_hl(0, "IndentLineContext", { fg = context_color })
end

-- Redraw all visible buffers
local function redraw_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and not should_exclude(buf) then
      draw_indent_lines(buf)
    end
  end
end

-- Apply initial highlights
apply_highlights()

-- Watch theme file for changes
local uv = vim.loop or vim.uv
if uv.fs_stat(theme_file) then
  local fs_event = uv.new_fs_event()
  fs_event:start(
    theme_file,
    {},
    vim.schedule_wrap(function()
      if theme_debounce_timer then
        theme_debounce_timer:stop()
      end
      theme_debounce_timer = vim.defer_fn(function()
        local new_theme = read_theme(theme_file) or "gruvbox"
        if new_theme ~= theme_current then
          theme_current = new_theme
          validate_config()
          apply_highlights()
          redraw_all_buffers()
        end
        theme_debounce_timer = nil
      end, 200)
    end)
  )
end

-- Clear exclusion cache when buffer is deleted
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(ev)
    exclusion_cache[ev.buf] = nil
    if timers[ev.buf] then
      timers[ev.buf]:stop()
      timers[ev.buf] = nil
    end
    -- Clear context cache if it's for this buffer
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
    -- Clear cache on FileType change
    if ev.event == "FileType" then
      exclusion_cache[ev.buf] = nil
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

-- Refresh on cursor movement for context highlighting
if config.show_current_context then
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      if not should_exclude(ev.buf) then
        draw_debounced(ev.buf)
      end
    end,
  })
end

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

-- Command to switch themes
vim.api.nvim_create_user_command("IndentLinesTheme", function(opts)
  local theme = opts.args
  if colors[theme] then
    theme_current = theme
    validate_config()
    apply_highlights()
    redraw_all_buffers()
    vim.notify("Theme changed to: " .. theme, vim.log.levels.INFO)
  else
    local available = table.concat(vim.tbl_keys(colors), ", ")
    vim.notify("Unknown theme: " .. theme .. ". Available: " .. available, vim.log.levels.ERROR)
  end
end, {
  nargs = 1,
  complete = function()
    return vim.tbl_keys(colors)
  end,
})

-- Command to reload configuration
vim.api.nvim_create_user_command("IndentLinesReload", function()
  validate_config()
  apply_highlights()
  redraw_all_buffers()
  vim.notify("Indent lines reloaded", vim.log.levels.INFO)
end, {})

-- Expose config for runtime access (optional, for advanced users)
_G.IndentLinesConfig = config

-- Validate config on startup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(validate_config, 50)
  end,
})
