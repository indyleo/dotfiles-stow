-- colorizer.lua

local ns = vim.api.nvim_create_namespace "colorizer"
local hl_cache = {}

local function contrast_fg(r, g, b)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5 and "#000000" or "#ffffff"
end

local function get_hl_group(r, g, b)
  local key = string.format("%02x%02x%02x", r, g, b)
  if not hl_cache[key] then
    local group = "Colorizer_" .. key
    vim.api.nvim_set_hl(0, group, {
      bg = "#" .. key,
      fg = contrast_fg(r, g, b),
    })
    hl_cache[key] = group
  end
  return hl_cache[key]
end

local function hsl_to_rgb(h, s, l)
  s, l = s / 100, l / 100
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
  return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
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

local function find_colors(line)
  local results = {}

  -- #RRGGBB
  for s, hex, e in line:gmatch "()#(%x%x%x%x%x%x)()" do
    table.insert(results, {
      col = s - 1,
      end_col = e - 1,
      r = tonumber(hex:sub(1, 2), 16),
      g = tonumber(hex:sub(3, 4), 16),
      b = tonumber(hex:sub(5, 6), 16),
    })
  end

  -- #RGB (only if NOT followed by more hex digits, so #RRGGBB isn't matched here)
  for s, hex, e in line:gmatch "()#(%x%x%x)()" do
    local next_char = line:sub(e, e)
    if not next_char:match "%x" then
      local r1, g1, b1 = hex:sub(1, 1), hex:sub(2, 2), hex:sub(3, 3)
      table.insert(results, {
        col = s - 1,
        end_col = e - 1,
        r = tonumber(r1 .. r1, 16),
        g = tonumber(g1 .. g1, 16),
        b = tonumber(b1 .. b1, 16),
      })
    end
  end

  -- rgb(R, G, B)
  for s, _, r, g, b, e in line:gmatch "()(rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%))()" do
    table.insert(results, {
      col = s - 1,
      end_col = e - 1,
      r = tonumber(r),
      g = tonumber(g),
      b = tonumber(b),
    })
  end

  -- rgba(R, G, B, A)
  for s, _, r, g, b, e in line:gmatch "()(rgba%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*[%d%.]+%s*%))()" do
    table.insert(results, {
      col = s - 1,
      end_col = e - 1,
      r = tonumber(r),
      g = tonumber(g),
      b = tonumber(b),
    })
  end

  -- hsl(H, S%, L%)
  for s, _, h, sv, lv, e in line:gmatch "()(hsl%(%s*(%d+)%s*,%s*(%d+)%%%s*,%s*(%d+)%%%s*%))()" do
    local r, g, b = hsl_to_rgb(tonumber(h), tonumber(sv), tonumber(lv))
    table.insert(results, { col = s - 1, end_col = e - 1, r = r, g = g, b = b })
  end

  -- hsla(H, S%, L%, A)
  for s, _, h, sv, lv, e in line:gmatch "()(hsla%(%s*(%d+)%s*,%s*(%d+)%%%s*,%s*(%d+)%%%s*,%s*[%d%.]+%s*%))()" do
    local r, g, b = hsl_to_rgb(tonumber(h), tonumber(sv), tonumber(lv))
    table.insert(results, { col = s - 1, end_col = e - 1, r = r, g = g, b = b })
  end

  -- named colors
  local lower = line:lower()
  for name, rgb in pairs(named_colors) do
    local start = 1
    while true do
      local s, e = lower:find(name, start, true)
      if not s then
        break
      end
      local before = s == 1 or not lower:sub(s - 1, s - 1):match "%a"
      local after = e == #line or not lower:sub(e + 1, e + 1):match "%a"
      if before and after then
        table.insert(results, {
          col = s - 1,
          end_col = e,
          r = rgb[1],
          g = rgb[2],
          b = rgb[3],
        })
      end
      start = e + 1
    end
  end

  return results
end

local function colorize(bufnr, firstline, lastline)
  firstline = firstline or 0
  lastline = lastline or -1

  vim.api.nvim_buf_clear_namespace(bufnr, ns, firstline, lastline)

  local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, lastline, false)
  for i, line in ipairs(lines) do
    local lnum = firstline + i - 1
    for _, m in ipairs(find_colors(line)) do
      vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, m.col, {
        end_col = m.end_col,
        hl_group = get_hl_group(m.r, m.g, m.b),
      })
    end
  end
end

local allow = {
  css = true,
  html = true,
  lua = true,
  javascript = true,
  typescript = true,
  tsx = true,
  jsx = true,
  scss = true,
  sass = true,
}

local attached = {}

local function attach(bufnr)
  local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
  if ok and stats and stats.size > 100 * 1024 then
    return
  end
  if vim.api.nvim_buf_line_count(bufnr) > 5000 then
    return
  end

  local ft = vim.bo[bufnr].filetype
  if not allow[ft] then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if not allow[ft] then
    return
  end
  if attached[bufnr] then
    return
  end
  attached[bufnr] = true

  colorize(bufnr)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, firstline, _, new_lastline)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          colorize(buf, firstline, new_lastline)
        end
      end)
    end,
    on_detach = function(_, buf)
      attached[buf] = nil
    end,
  })
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter" }, {
  callback = function(ev)
    attach(ev.buf)
  end,
})

vim.api.nvim_create_user_command("ColorizerToggle", function()
  local buf = vim.api.nvim_get_current_buf()
  if attached[buf] then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    attached[buf] = nil
  else
    local ft = vim.bo[buf].filetype
    allow[ft] = true
    attach(buf)
  end
end, {})
