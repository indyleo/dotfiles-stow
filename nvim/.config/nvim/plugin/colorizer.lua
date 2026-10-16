-- colorizer.lua
local api = vim.api
local uv = vim.uv or vim.loop
local unpack = table.unpack or unpack

local ns = api.nvim_create_namespace "colorizer"
local hl_cache = {}
local attached = {}
local disabled = {}
local forced = {} -- buffers enabled manually, regardless of filetype

local MAX_FILE_SIZE = 100 * 1024
local MAX_LINES = 5000
local DEBOUNCE_MS = 150

local function clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

local function is_word(ch)
  return ch ~= "" and ch:match "[%w_]" ~= nil
end

local function valid_rgb(r, g, b)
  r, g, b = tonumber(r), tonumber(g), tonumber(b)
  if not r or not g or not b then
    return nil
  end

  if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 then
    return nil
  end

  return math.floor(r), math.floor(g), math.floor(b)
end

local function contrast_fg(r, g, b)
  -- Luma approximation, sufficient for readable swatches.
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5 and "#000000" or "#ffffff"
end

-- Highlight group with background r,g,b. If fr,fgc,fb are given they are used
-- as the foreground, otherwise a contrasting black/white is chosen.
local function get_hl_group(r, g, b, fr, fgc, fb)
  r, g, b = valid_rgb(r, g, b)
  if not r then
    return nil
  end

  local key = string.format("%02x%02x%02x", r, g, b)
  local fg_hex
  if fr then
    fr, fgc, fb = valid_rgb(fr, fgc, fb)
    if fr then
      fg_hex = string.format("%02x%02x%02x", fr, fgc, fb)
      key = key .. "_" .. fg_hex
    end
  end

  local group = hl_cache[key]
  if not group then
    group = "Colorizer_" .. key
    api.nvim_set_hl(0, group, {
      bg = "#" .. key:sub(1, 6),
      fg = fg_hex and ("#" .. fg_hex) or contrast_fg(r, g, b),
    })
    hl_cache[key] = group
  end

  return group
end

local function hsl_to_rgb(h, s, l)
  h, s, l = tonumber(h), tonumber(s), tonumber(l)
  if not h or not s or not l then
    return nil
  end

  h = h % 360
  s = clamp(s, 0, 100) / 100
  l = clamp(l, 0, 100) / 100

  local c = (1 - math.abs(2 * l - 1)) * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = l - c / 2
  local r, g, b

  if h < 60 then
    r, g, b = c, x, 0
  elseif h < 120 then
    r, g, b = x, c, 0
  elseif h < 180 then
    r, g, b = 0, c, x
  elseif h < 240 then
    r, g, b = 0, x, c
  elseif h < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  return math.floor((r + m) * 255 + 0.5), math.floor((g + m) * 255 + 0.5), math.floor((b + m) * 255 + 0.5)
end

local named_colors = {
  red = { 255, 0, 0 },
  green = { 0, 128, 0 },
  blue = { 0, 0, 255 },
  white = { 255, 255, 255 },
  black = { 0, 0, 0 },
  yellow = { 255, 255, 0 },
  orange = { 255, 165, 0 },
  purple = { 128, 0, 128 },
  pink = { 255, 192, 203 },
  cyan = { 0, 255, 255 },
  magenta = { 255, 0, 255 },
  lime = { 0, 255, 0 },
  brown = { 165, 42, 42 },
  gray = { 128, 128, 128 },
  grey = { 128, 128, 128 },
  silver = { 192, 192, 192 },
  navy = { 0, 0, 128 },
  teal = { 0, 128, 128 },
  maroon = { 128, 0, 0 },
  olive = { 128, 128, 0 },
  coral = { 255, 127, 80 },
  salmon = { 250, 128, 114 },
  gold = { 255, 215, 0 },
  violet = { 238, 130, 238 },
  indigo = { 75, 0, 130 },
  crimson = { 220, 20, 60 },
  turquoise = { 64, 224, 208 },
  lavender = { 230, 230, 250 },
  beige = { 245, 245, 220 },
  ivory = { 255, 255, 240 },
  khaki = { 240, 230, 140 },
  plum = { 221, 160, 221 },
  tan = { 210, 180, 140 },
  tomato = { 255, 99, 71 },
  orchid = { 218, 112, 214 },
  peru = { 205, 133, 63 },
  sienna = { 160, 82, 45 },
  chocolate = { 210, 105, 30 },
  wheat = { 245, 222, 179 },
  linen = { 250, 240, 230 },
  snow = { 255, 250, 250 },
  azure = { 240, 255, 255 },
  aqua = { 0, 255, 255 },
  fuchsia = { 255, 0, 255 },
}

-- Named colors are prone to false positives ("red", "tan", "gold" in comments
-- or identifiers), so only look for them in style-oriented filetypes.
local named_ft = {
  css = true,
  scss = true,
  sass = true,
  html = true,
}

-- Standard xterm palette for the 16 ANSI colors.
local basic_palette = {
  { 0, 0, 0 },
  { 205, 0, 0 },
  { 0, 205, 0 },
  { 205, 205, 0 },
  { 0, 0, 238 },
  { 205, 0, 205 },
  { 0, 205, 205 },
  { 229, 229, 229 },
  { 127, 127, 127 },
  { 255, 0, 0 },
  { 0, 255, 0 },
  { 255, 255, 0 },
  { 92, 92, 255 },
  { 255, 0, 255 },
  { 0, 255, 255 },
  { 255, 255, 255 },
}

local function add_result(results, seen, s, e, r, g, b, fg)
  r, g, b = valid_rgb(r, g, b)
  if not r or not s or not e or e <= s then
    return
  end

  -- Columns are zero-based byte offsets; e is exclusive.
  local key = s .. ":" .. e
  if seen[key] then
    return
  end
  seen[key] = true

  results[#results + 1] = {
    col = s,
    end_col = e,
    r = r,
    g = g,
    b = b,
    fg = fg, -- optional { r, g, b } foreground (ANSI fg + bg combined)
  }
end

-- Accepts 3, 4 (#rgba), 6 or 8 (#rrggbbaa) digits. Alpha is ignored.
local function hex_to_rgb(hex)
  if #hex == 3 or #hex == 4 then
    return tonumber(hex:sub(1, 1):rep(2), 16), tonumber(hex:sub(2, 2):rep(2), 16), tonumber(hex:sub(3, 3):rep(2), 16)
  end

  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function xterm_to_rgb(n)
  n = tonumber(n)
  if not n or n < 0 or n > 255 then
    return nil
  end

  n = math.floor(n)

  if n < 16 then
    return unpack(basic_palette[n + 1])
  end

  if n >= 232 then
    local v = 8 + (n - 232) * 10
    return v, v, v
  end

  n = n - 16
  local levels = { 0, 95, 135, 175, 215, 255 }
  return levels[math.floor(n / 36) + 1], levels[math.floor(n / 6) % 6 + 1], levels[n % 6 + 1]
end

-- Parse the parameter list of an SGR sequence ("1;31", "38;5;196",
-- "38;2;255;0;0;48;5;17", ...). Returns the effective fg and bg as
-- { r, g, b } tables (either may be nil).
local function parse_sgr(params)
  if not params:match "^[%d;]*$" then
    -- printf-style placeholder such as \033[%sm: the color is only known at
    -- runtime, so report it as dynamic instead of guessing.
    if params:gsub("%%[sdb]", ""):match "^[%d;]*$" then
      return "dynamic"
    end
    return nil
  end

  local codes = {}
  for n in (params .. ";"):gmatch "(.-);" do
    codes[#codes + 1] = tonumber(n) or 0 -- empty parameter means 0
  end

  local fg, bg
  local i = 1
  while i <= #codes do
    local c = codes[i]

    if c == 38 or c == 48 then
      local mode = codes[i + 1]
      local r, g, b

      if mode == 2 then
        r, g, b = valid_rgb(codes[i + 2], codes[i + 3], codes[i + 4])
        i = i + 5
      elseif mode == 5 then
        r, g, b = xterm_to_rgb(codes[i + 2])
        i = i + 3
      else
        i = i + 2
      end

      if r then
        if c == 38 then
          fg = { r, g, b }
        else
          bg = { r, g, b }
        end
      end
    else
      if c == 0 then
        fg, bg = nil, nil
      elseif c == 39 then
        fg = nil
      elseif c == 49 then
        bg = nil
      elseif c >= 30 and c <= 37 then
        fg = basic_palette[c - 30 + 1]
      elseif c >= 90 and c <= 97 then
        fg = basic_palette[c - 90 + 9]
      elseif c >= 40 and c <= 47 then
        bg = basic_palette[c - 40 + 1]
      elseif c >= 100 and c <= 107 then
        bg = basic_palette[c - 100 + 9]
      end
      i = i + 1
    end
  end

  return fg, bg
end

-- Ways an ESC can be written in source files. Patterns are matched literally
-- (backslash is not special in Lua patterns).
local esc_patterns = {
  "\27%[([%d;%%sdb]*)m", -- a real ESC byte
  "\\033%[([%d;%%sdb]*)m", -- \033
  "\\e%[([%d;%%sdb]*)m", -- \e
  "\\x1[bB]%[([%d;%%sdb]*)m", -- \x1b / \x1B
  "\\u001[bB]%[([%d;%%sdb]*)m", -- \u001b
  "\\u{1[bB]}%[([%d;%%sdb]*)m", -- \u{1b}
}

local function find_colors(line, with_names)
  local results, seen = {}, {}

  -- #rgb, #rgba, #rrggbb, #rrggbbaa. Boundary checks make the order irrelevant.
  for _, len in ipairs { 8, 6, 4, 3 } do
    local pat = "()#(" .. ("%x"):rep(len) .. ")()"
    for s, hex, e in line:gmatch(pat) do
      local prev_char = line:sub(s - 1, s - 1)
      local next_char = line:sub(e, e)

      -- "&" skips HTML numeric entities such as &#123;
      if not is_word(prev_char) and prev_char ~= "&" and not is_word(next_char) then
        add_result(results, seen, s - 1, e - 1, hex_to_rgb(hex))
      end
    end
  end

  -- 0xRRGGBB, 0xAARRGGBB, and underscore-separated variants.
  -- Examples:
  --   0x282828
  --   0xFF282828
  --   0xFF28_2828
  --   0xFFB8_BB26
  --   0xFF_28_28_28
  --
  -- For 8-digit 0x values, interpret the format as AARRGGBB.
  -- Alpha is ignored.

  for s, hex, e in line:gmatch "()(0[xX][%x_]+)()" do
    local prev_char = line:sub(s - 1, s - 1)
    local next_char = line:sub(e, e)

    if not is_word(prev_char) and not is_word(next_char) then
      local digits = hex:sub(3)
      local valid_format = digits:match "^%x%x%x%x%x%x$"
        or digits:match "^%x%x%x%x%x%x%x%x$"
        or digits:match "^%x%x%x%x_%x%x%x%x$"
        or digits:match "^%x%x_%x%x_%x%x_%x%x$"

      if valid_format then
        digits = digits:gsub("_", "")

        if #digits == 8 then
          -- AARRGGBB: discard the first byte (alpha).
          digits = digits:sub(3)
        end

        add_result(results, seen, s - 1, e - 1, hex_to_rgb(digits))
      end
    end
  end

  -- CSS rgb()/rgba(): comma syntax and modern space syntax (optional alpha).
  for s, r, g, b, e in line:gmatch "()%f[%w_]rgba?%(%s*(%d+)[%s,]+(%d+)[%s,]+(%d+)[%s,/]*[%d%.]*%%?%s*%)()" do
    add_result(results, seen, s - 1, e - 1, r, g, b)
  end

  -- CSS hsl()/hsla()
  for s, h, sat, light, e in line:gmatch "()%f[%w_]hsla?%(%s*(%-?[%d%.]+)[deg]*[%s,]+([%d%.]+)%%[%s,]+([%d%.]+)%%[%s,/]*[%d%.]*%%?%s*%)()" do
    local r, g, b = hsl_to_rgb(h, sat, light)
    add_result(results, seen, s - 1, e - 1, r, g, b)
  end

  -- ANSI SGR escape sequences, written as a real ESC, \033, \e, \x1b, \u001b
  -- or \u{1b}. Supports 16 colors (30-37, 40-47, 90-97, 100-107), 256 colors
  -- (38;5;n / 48;5;n) and truecolor (38;2;r;g;b / 48;2;r;g;b).
  for _, pattern in ipairs(esc_patterns) do
    for s, params, e in line:gmatch("()" .. pattern .. "()") do
      local fg, bg = parse_sgr(params)

      if fg == "dynamic" then
        add_result(results, seen, s - 1, e - 1, 128, 128, 128, "dynamic")
      elseif fg and bg then
        -- Show the sequence the way the terminal would: fg text on bg.
        add_result(results, seen, s - 1, e - 1, bg[1], bg[2], bg[3], fg)
      elseif fg or bg then
        local c = fg or bg
        add_result(results, seen, s - 1, e - 1, c[1], c[2], c[3])
      end
    end
  end

  -- Standalone CSS color names, matched as whole identifiers so "red" does not
  -- match inside "hundred" or "red_value", nor in "text-red" / ".red".
  if with_names then
    local lower = line:lower()
    for s, word, e in lower:gmatch "()([%w_]+)()" do
      local rgb = named_colors[word]
      if rgb then
        local prev_char = lower:sub(s - 1, s - 1)
        local next_char = lower:sub(e, e)
        if not prev_char:match "[%-%.#$@]" and next_char ~= "-" then
          add_result(results, seen, s - 1, e - 1, rgb[1], rgb[2], rgb[3])
        end
      end
    end
  end

  -- Sort for deterministic extmark placement and reject overlapping spans.
  table.sort(results, function(a, b)
    if a.col == b.col then
      return a.end_col > b.end_col
    end
    return a.col < b.col
  end)

  local filtered = {}
  local last_end = -1
  for _, item in ipairs(results) do
    if item.col >= last_end then
      filtered[#filtered + 1] = item
      last_end = item.end_col
    end
  end

  return filtered
end

local DYNAMIC_GROUP = "ColorizerDynamic"

local function colorize(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Neutral style for escapes whose color is decided at runtime (\033[%sm).
  api.nvim_set_hl(0, DYNAMIC_GROUP, { bg = "#555555", fg = "#ffffff", italic = true })

  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local line_count = api.nvim_buf_line_count(bufnr)
  if line_count > MAX_LINES then
    return
  end

  local with_names = named_ft[vim.bo[bufnr].filetype] or false
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for lnum, line in ipairs(lines) do
    for _, m in ipairs(find_colors(line, with_names)) do
      local group
      if m.fg == "dynamic" then
        group = DYNAMIC_GROUP
      elseif m.fg then
        group = get_hl_group(m.r, m.g, m.b, m.fg[1], m.fg[2], m.fg[3])
      else
        group = get_hl_group(m.r, m.g, m.b)
      end

      if group then
        pcall(api.nvim_buf_set_extmark, bufnr, ns, lnum - 1, m.col, {
          end_col = m.end_col,
          hl_group = group,
          priority = 110,
        })
      end
    end
  end
end

local allow = {
  css = true,
  html = true,
  lua = true,
  javascript = true,
  typescript = true,
  typescriptreact = true,
  javascriptreact = true,
  tsx = true,
  jsx = true,
  scss = true,
  sass = true,
  c = true,
  cpp = true,
  rust = true,
  python = true,
  sh = true,
  bash = true,
  zsh = true,
  fish = true,
}

local function stop_timer(timer)
  if not timer then
    return
  end

  pcall(function()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end)
end

local function attach(bufnr, force)
  if not api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if disabled[bufnr] or attached[bufnr] then
    return false
  end

  local name = api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    local ok, stats = pcall(uv.fs_stat, name)
    if ok and stats and stats.size > MAX_FILE_SIZE then
      return false
    end
  end

  if api.nvim_buf_line_count(bufnr) > MAX_LINES then
    return false
  end

  if force then
    forced[bufnr] = true
  end

  if not (forced[bufnr] or allow[vim.bo[bufnr].filetype]) then
    return false
  end

  local state = { timer = nil }
  attached[bufnr] = state

  colorize(bufnr)

  local ok = api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      -- A stale callback (from before a disable/enable cycle) detaches itself,
      -- so toggling never stacks up duplicate listeners.
      if attached[buf] ~= state or disabled[buf] then
        return true
      end

      stop_timer(state.timer)

      local timer = uv.new_timer()
      state.timer = timer

      timer:start(
        DEBOUNCE_MS,
        0,
        vim.schedule_wrap(function()
          if state.timer ~= timer then
            return -- superseded by a newer edit
          end

          state.timer = nil
          stop_timer(timer)

          if attached[buf] == state and api.nvim_buf_is_valid(buf) and not disabled[buf] then
            colorize(buf)
          end
        end)
      )
    end,

    on_detach = function(_, buf)
      stop_timer(state.timer)
      state.timer = nil
      if attached[buf] == state then
        attached[buf] = nil
      end
    end,
  })

  if not ok then
    attached[bufnr] = nil
    return false
  end

  return true
end

local function detach_colorizer(bufnr)
  disabled[bufnr] = true

  local state = attached[bufnr]
  if state then
    stop_timer(state.timer)
    state.timer = nil
    attached[bufnr] = nil
  end

  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter", "FileType" }, {
  callback = function(ev)
    attach(ev.buf)
  end,
})

-- :colorscheme runs ":hi clear", which wipes our Colorizer_* groups.
-- Drop the cache and repaint so the swatches come back.
api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    hl_cache = {}
    for buf in pairs(attached) do
      colorize(buf)
    end
  end,
})

api.nvim_create_autocmd("BufWipeout", {
  callback = function(ev)
    local state = attached[ev.buf]
    if state then
      stop_timer(state.timer)
    end

    attached[ev.buf] = nil
    disabled[ev.buf] = nil
    forced[ev.buf] = nil
  end,
})

api.nvim_create_user_command("ColorizerEnable", function()
  local bufnr = api.nvim_get_current_buf()
  disabled[bufnr] = nil
  if not attached[bufnr] and not attach(bufnr, true) then
    vim.notify("colorizer: buffer is too large to colorize", vim.log.levels.WARN)
  end
end, {})

api.nvim_create_user_command("ColorizerDisable", function()
  detach_colorizer(api.nvim_get_current_buf())
end, {})

api.nvim_create_user_command("ColorizerToggle", function()
  local bufnr = api.nvim_get_current_buf()

  if attached[bufnr] then
    detach_colorizer(bufnr)
  else
    disabled[bufnr] = nil
    if not attach(bufnr, true) then
      vim.notify("colorizer: buffer is too large to colorize", vim.log.levels.WARN)
    end
  end
end, {})
