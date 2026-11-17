-- =============================================================================
-- image-hover.lua  --  hover a file path, see the image in a popup
--
-- Target:    Neovim >= 0.12.6
-- Location:  ~/.config/nvim/plugin/image-hover.lua   (single file, no lua/ tree)
--
-- What it does: when the cursor rests on (or the mouse hovers over) a file path
-- in ANY buffer -- absolute, relative, ~/..., $VAR/..., file://..., markdown
-- `![alt](img.png)`, quoted strings, `path.png:12` -- it resolves the path,
-- checks the FILE CONTENT (magic bytes, not just the extension) and, only if it
-- is an image, opens a floating popup:
--   1. sixel   : via the companion `sixel-render.lua` (_G.sixel_render),
--                resolved lazily at every call.
--   2. ASCII   : when sixel is unsupported, conversion fails, or placement
--                fails: `chafa --format symbols` (coloured with --colors 256
--                by default, `chafa_colors = "none"` for plain text).
--   3. nothing : not an image / file not found / no renderer available
--                (one vim.notify_once in the last case).
--
-- Dependencies:
--   * sixel path : sixel-render.lua (+ img2sixel | chafa | ImageMagick).
--   * ASCII path : `chafa` (any image format it can read).
--   * Non-PNG images (jpg/gif/webp/bmp/tiff/avif/svg) need ONE converter for
--     the sixel path: `magick`/`convert`, `ffmpeg`, or `rsvg-convert` (svg).
--     Without a converter those files fall back to chafa ASCII.
--   No third-party Lua plugins, no image.nvim.
--
-- Triggers (cfg.trigger): "cursor" (default; cursor rests `delay_ms` on a path),
--   "mouse" (needs 'mousemoveevent', set automatically), or "both".
--
-- Commands: :ImageHover  :ImageHoverClose  :ImageHoverToggle
--
-- Config (all optional):
--   require("image-hover").setup{ trigger = "both", max_width = 70 }
--   (call from a VimEnter autocmd / after/ file; `_G.image_hover` also exists.
--    Zero-config works: setup{} runs on VimEnter.)
-- =============================================================================

if vim.fn.has("nvim-0.12.6") ~= 1 then
  vim.notify("image-hover requires Neovim >= 0.12.6 (found " ..
             tostring(vim.version()) .. ")", vim.log.levels.ERROR)
  return
end

local api = vim.api
local uv = vim.uv

local M = {}
package.loaded["image-hover"] = M
_G.image_hover = M

local ns = api.nvim_create_namespace("image-hover")
local aug = api.nvim_create_augroup("ImageHover", { clear = true })

-- -----------------------------------------------------------------------------
-- Config
-- -----------------------------------------------------------------------------
local defaults = {
  enabled            = true,
  trigger            = "cursor",   -- "cursor" | "mouse" | "both"
  delay_ms           = 250,
  max_width          = 60,         -- cells
  max_height         = 25,         -- cells
  border             = "rounded",
  buftypes           = { "" },     -- only hover in these buffer types
  exclude_filetypes  = {},
  cache_dir          = vim.fs.joinpath(vim.fn.stdpath("cache"), "image-hover"),
  convert            = true,       -- convert non-PNG to PNG for the sixel path
  chafa_cmd          = nil,        -- nil = { "chafa" }
  chafa_colors       = "256",      -- "none" | "2" | "16" | "256" | "full"
  chafa_symbols      = "block+border+space",
  chafa_extra_args   = {},
  highlights = { popup = "ImageHoverPopup", border = "ImageHoverBorder" },
}
local cfg = vim.deepcopy(defaults)

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------
local popup = {}            -- { win, handle, key, span = {row, s, e}, source }
local scratch_buf = nil
local gen = 0               -- bumped on every close; stale async results compare against it
local job = nil             -- in-flight vim.system handle (convert / chafa)
local timer = nil
local mem = {}              -- chafa output memo
local hl_made = {}

-- -----------------------------------------------------------------------------
-- Provider (sixel-render), lazy and null-safe
-- -----------------------------------------------------------------------------
local function provider()
  return _G.sixel_render or package.loaded["sixel-render"]
end

local function P(fn, ...)
  local p = provider()
  if not p or not p.supports() then return nil end
  return p[fn](...)
end

local function sixel_ok()
  local p = provider()
  return p ~= nil and p.supports() == true
end

local function chafa_base() return cfg.chafa_cmd or { "chafa" } end
local function have_chafa() return vim.fn.exepath(chafa_base()[1]) ~= "" end

-- -----------------------------------------------------------------------------
-- Path discovery under the cursor / mouse
-- -----------------------------------------------------------------------------
local PAIRS = { { "(", ")" }, { "[", "]" }, { "<", ">" }, { '"', '"' }, { "'", "'" },
                { "`", "`" }, { "{", "}" } }

--- Delimited segments (brackets / quotes) that contain 1-based `col`.
local function enclosed(line, col)
  local out = {}
  for _, pr in ipairs(PAIRS) do
    local o, c = pr[1], pr[2]
    local s, e
    if o == c then
      local open
      for i = 1, #line do
        if line:sub(i, i) == o then
          if not open then
            open = i
          else
            if open <= col and col <= i then s, e = open, i end
            open = nil
          end
        end
      end
    else
      for i = col - 1, 1, -1 do
        if line:sub(i, i) == o then s = i break end
      end
      for i = col + 1, #line do
        if line:sub(i, i) == c then e = i break end
      end
    end
    if s and e and e - s > 1 then
      out[#out + 1] = { text = line:sub(s + 1, e - 1), s = s + 1, e = e - 1 }
    end
  end
  table.sort(out, function(a, b) return (a.e - a.s) < (b.e - b.s) end)
  return out
end

local function is_delim(ch)
  return ch == "" or ch:match("[%s\"'`()<>%[%]{}|,;]") ~= nil
end

--- Whitespace/bracket/quote-delimited token around 1-based `col`.
local function token(line, col)
  if is_delim(line:sub(col, col)) then return nil end
  local s, e = col, col
  while s > 1 and not is_delim(line:sub(s - 1, s - 1)) do s = s - 1 end
  while e < #line and not is_delim(line:sub(e + 1, e + 1)) do e = e + 1 end
  return { text = line:sub(s, e), s = s, e = e }
end

--- Strip markdown titles, queries/fragments, :line:col suffixes, trailing punctuation.
local function clean(s)
  s = vim.trim(s)
  s = s:gsub("%s+[\"'].*$", "")
  s = s:gsub("[?#].*$", "")
  s = s:gsub(":%d+:?%d*$", "")
  s = s:gsub("[%.,:;!?]+$", "")
  return s
end

local function is_file(p)
  local st = uv.fs_stat(p)
  return st ~= nil and st.type == "file"
end

--- Resolve a (possibly relative) path: as-is for absolute, else relative to the
--- buffer's directory, then cwd, then an upward `findfile` from the buffer dir.
local function resolve(s, bufname)
  s = s:gsub("^file://", "")
  if s == "" or s:match("^%a[%w+.-]*://") then return nil end
  if s:find("[~$]") then s = vim.fs.normalize(s) end
  local bdir
  if bufname ~= "" then
    bdir = vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(bufname, ":p")))
  end
  local cands = {}
  if s:match("^/") or s:match("^%a:[/\\]") then
    cands[1] = s
  else
    if bdir then cands[#cands + 1] = vim.fs.joinpath(bdir, s) end
    cands[#cands + 1] = vim.fs.joinpath(uv.cwd(), s)
  end
  for _, c in ipairs(cands) do
    c = vim.fs.normalize(c)
    if is_file(c) then return c end
  end
  if bdir and not s:match("^/") then
    local ok, f = pcall(vim.fn.findfile, s, bdir .. ";")
    if ok and f ~= "" then return vim.fs.normalize(vim.fn.fnamemodify(f, ":p")) end
  end
  return nil
end

--- Identify the image format from file content (magic bytes); svg by extension
--- plus an `<svg` tag. Returns nil for anything that is not a known image.
local function sniff(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local head = f:read(512)
  f:close()
  if not head or #head < 4 then return nil end
  local ext = (path:match("%.(%w+)$") or ""):lower()
  if head:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
  if head:sub(1, 3) == "\255\216\255" then return "jpeg" end
  if head:sub(1, 4) == "GIF8" then return "gif" end
  if head:sub(1, 4) == "RIFF" and head:sub(9, 12) == "WEBP" then return "webp" end
  if head:sub(1, 4) == "II*\0" or head:sub(1, 4) == "MM\0*" then return "tiff" end
  if head:sub(1, 2) == "BM" and ext == "bmp" then return "bmp" end
  if head:sub(5, 8) == "ftyp" and (head:sub(9, 12) == "avif" or head:sub(9, 12) == "avis") then
    return "avif"
  end
  if ext == "svg" and head:find("<svg", 1, true) then return "svg" end
  return nil
end

--- Find an image path at (row0, col0) (0-based) in `bufnr`.
--- Returns { path, kind, mtime, span = { row, s, e } } or nil.
local function find_target(bufnr, row0, col0)
  local line = api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if not line or line == "" then return nil end
  local col = col0 + 1
  local cands = enclosed(line, col)
  local tok = token(line, col)
  if tok then cands[#cands + 1] = tok end
  local bufname = api.nvim_buf_get_name(bufnr)
  for _, c in ipairs(cands) do
    for _, variant in ipairs({ clean(c.text), clean(c.text:match("^%S+") or "") }) do
      local path = variant ~= "" and resolve(variant, bufname) or nil
      if path then
        local kind = sniff(path)
        if kind then
          return { path = path, kind = kind, mtime = uv.fs_stat(path).mtime.sec,
                   span = { row = row0, s = c.s, e = c.e } }
        end
      end
    end
  end
  return nil
end

-- -----------------------------------------------------------------------------
-- Popup window
-- -----------------------------------------------------------------------------
local function scratch()
  if not scratch_buf or not api.nvim_buf_is_valid(scratch_buf) then
    scratch_buf = api.nvim_create_buf(false, true)
    vim.bo[scratch_buf].bufhidden = "hide"
  end
  return scratch_buf
end

local function set_content(lines)
  local buf = scratch()
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

local function open_float(w, h, anchor)
  w = math.max(1, math.min(w, vim.o.columns - 4))
  h = math.max(1, math.min(h, vim.o.lines - 4))
  local win = api.nvim_open_win(scratch(), false, {
    relative = anchor, row = 1, col = 0, width = w, height = h,
    style = "minimal", border = cfg.border, focusable = false,
    noautocmd = true, zindex = 60,
  })
  vim.wo[win].winhighlight = "Normal:" .. cfg.highlights.popup ..
                             ",FloatBorder:" .. cfg.highlights.border
  vim.wo[win].wrap = false
  return win, w, h
end

--- Close the popup, clear any sixel placement, cancel in-flight work.
function M.close()
  gen = gen + 1
  if job then pcall(job.kill, job, "sigterm"); job = nil end
  if popup.handle then P("clear", popup.handle) end
  if popup.win and api.nvim_win_is_valid(popup.win) then
    pcall(api.nvim_win_close, popup.win, true)
  end
  popup = {}
end

-- -----------------------------------------------------------------------------
-- chafa colour parsing (SGR -> highlight groups)
-- -----------------------------------------------------------------------------
local ANSI = { [0] = "#000000", "#cd0000", "#00cd00", "#cdcd00", "#0000ee", "#cd00cd", "#00cdcd", "#e5e5e5",
               "#7f7f7f", "#ff0000", "#00ff00", "#ffff00", "#5c5cff", "#ff00ff", "#00ffff", "#ffffff" }

local function palette256(n)
  if n < 16 then return ANSI[n] end
  if n >= 232 then
    local g = 8 + (n - 232) * 10
    return string.format("#%02x%02x%02x", g, g, g)
  end
  local lv = { [0] = 0, 95, 135, 175, 215, 255 }
  n = n - 16
  return string.format("#%02x%02x%02x", lv[math.floor(n / 36)], lv[math.floor(n / 6) % 6], lv[n % 6])
end

local function sgr(params, st)
  local codes = vim.iter(vim.split(params, ";", { plain = true }))
    :map(function(x) return tonumber(x) or 0 end):totable()
  local i = 1
  while i <= #codes do
    local c, adv = codes[i], 1
    if c == 0 then st.fg, st.bg = nil, nil
    elseif c == 39 then st.fg = nil
    elseif c == 49 then st.bg = nil
    elseif c >= 30 and c <= 37 then st.fg = ANSI[c - 30]
    elseif c >= 90 and c <= 97 then st.fg = ANSI[c - 90 + 8]
    elseif c >= 40 and c <= 47 then st.bg = ANSI[c - 40]
    elseif c >= 100 and c <= 107 then st.bg = ANSI[c - 100 + 8]
    elseif c == 38 or c == 48 then
      local color
      if codes[i + 1] == 5 and codes[i + 2] then
        color, adv = palette256(codes[i + 2]), 3
      elseif codes[i + 1] == 2 and codes[i + 4] then
        color = string.format("#%02x%02x%02x", codes[i + 2], codes[i + 3], codes[i + 4])
        adv = 5
      end
      if c == 38 then st.fg = color else st.bg = color end
    end
    i = i + adv
  end
end

local function parse_line(line)
  local chunks, st, pos = {}, {}, 1
  local function push(text)
    if text == "" then return end
    local last = chunks[#chunks]
    if last and last.fg == st.fg and last.bg == st.bg then
      last.text = last.text .. text
    else
      chunks[#chunks + 1] = { text = text, fg = st.fg, bg = st.bg }
    end
  end
  while pos <= #line do
    local s, e, params, final = line:find("\27%[([%d;?]*)(%a)", pos)
    push(line:sub(pos, (s or #line + 1) - 1))
    if not s then break end
    if final == "m" then sgr(params, st) end
    pos = e + 1
  end
  return chunks
end

local function chunk_hl(fg, bg)
  local name = "ImageHoverChafa_" .. vim.fn.sha256((fg or "") .. "|" .. (bg or ""))
  if not hl_made[name] then
    api.nvim_set_hl(0, name, { fg = fg, bg = bg, default = true })
    hl_made[name] = true
  end
  return name
end

-- -----------------------------------------------------------------------------
-- Backends
-- -----------------------------------------------------------------------------
--- ASCII backend: `chafa --format symbols` (async, cancellable). Shows nothing
--- (plus one notify_once) when chafa is missing.
local function show_ascii(t, anchor, my)
  if not have_chafa() then
    vim.notify_once("image-hover: no sixel support and `chafa` not found; " ..
      "image popups are disabled.", vim.log.levels.WARN)
    return
  end
  local w, h = cfg.max_width, cfg.max_height
  local key = table.concat({ t.path, t.mtime, w .. "x" .. h, cfg.chafa_colors,
    cfg.chafa_symbols, vim.inspect(cfg.chafa_extra_args) }, "|")

  local function render(raw)
    local lines = vim.split(raw, "\n", { plain = true })
    while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
    if #lines == 0 then return end
    local texts, chunk_rows, width = {}, {}, 1
    for i, l in ipairs(lines) do
      if cfg.chafa_colors == "none" then
        texts[i] = (l:gsub("\27%[[%d;?]*%a", ""))
      else
        local chunks = parse_line(l)
        chunk_rows[i] = chunks
        texts[i] = vim.iter(chunks):map(function(c) return c.text end):join("")
      end
      width = math.max(width, vim.fn.strdisplaywidth(texts[i]))
    end
    local buf = set_content(texts)
    for row, chunks in pairs(chunk_rows) do
      local col = 0
      for _, c in ipairs(chunks) do
        local len = #c.text
        if c.fg or c.bg then
          api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
            end_col = col + len, hl_group = chunk_hl(c.fg, c.bg), priority = 100,
          })
        end
        col = col + len
      end
    end
    popup.win = open_float(width, #texts, anchor)
  end

  if mem[key] then return render(mem[key]) end
  local cmd = vim.list_extend(vim.deepcopy(chafa_base()), {
    "--format", "symbols", "--colors", cfg.chafa_colors, "--symbols", cfg.chafa_symbols,
    "--size", w .. "x" .. h, "--animate", "off" })
  vim.list_extend(cmd, cfg.chafa_extra_args)
  cmd[#cmd + 1] = t.path
  local ok, obj = pcall(vim.system, cmd, { text = true }, vim.schedule_wrap(function(res)
    if my ~= gen then return end
    job = nil
    if res.code ~= 0 or not res.stdout or res.stdout == "" then return end
    if vim.tbl_count(mem) > 20 then mem = {} end
    mem[key] = res.stdout
    render(res.stdout)
  end))
  if ok then job = obj end
end

--- Make a PNG for the sixel path: PNGs pass through, other formats are
--- converted once (cached) with magick/convert, ffmpeg or rsvg-convert.
local function ensure_png(t, cb)
  if t.kind == "png" then return cb(t.path) end
  if not cfg.convert then return cb(nil) end
  local dir = vim.fs.joinpath(cfg.cache_dir, "converted")
  local out = vim.fs.joinpath(dir, vim.fn.sha256(t.path .. t.mtime) .. ".png")
  if uv.fs_stat(out) then return cb(out) end
  local tmp = out .. ".part.png"
  local cmd
  if t.kind == "svg" and vim.fn.exepath("rsvg-convert") ~= "" then
    cmd = { "rsvg-convert", "-o", tmp, t.path }
  else
    for _, bin in ipairs({ "magick", "convert" }) do
      if vim.fn.exepath(bin) ~= "" then cmd = { bin, t.path .. "[0]", tmp } break end
    end
    if not cmd and vim.fn.exepath("ffmpeg") ~= "" then
      cmd = { "ffmpeg", "-v", "error", "-y", "-i", t.path, "-frames:v", "1", tmp }
    end
  end
  if not cmd then return cb(nil) end
  vim.fn.mkdir(dir, "p")
  local my = gen
  local ok, obj = pcall(vim.system, cmd, { text = true }, vim.schedule_wrap(function(res)
    if my ~= gen then return end
    job = nil
    if res.code == 0 and uv.fs_stat(tmp) then
      pcall(uv.fs_rename, tmp, out)
      return cb(out)
    end
    cb(nil)
  end))
  if ok then job = obj else cb(nil) end
end

--- Sixel backend: float sized to the image, pixels via sixel_render.place
--- (float = true, row/col 0-based window-relative). Any failure -> ASCII.
local function show_sixel(t, anchor, my)
  ensure_png(t, function(png)
    if my ~= gen then return end
    if not png then return show_ascii(t, anchor, my) end
    local wc, hc = cfg.max_width, cfg.max_height
    local p = provider()
    if p and p.measure then
      local a, b = p.measure(png, cfg.max_width, cfg.max_height)
      if a then wc, hc = a, b end
    end
    set_content(vim.fn["repeat"]({ "" }, math.max(1, hc)))
    local win, w, h = open_float(wc, hc, anchor)
    local handle = P("place", {
      bufnr = api.nvim_get_current_buf(), winid = win, row = 0, col = 0, path = png,
      id = "image-hover", width_cells = w, height_cells = h, float = true,
    })
    if not handle then
      pcall(api.nvim_win_close, win, true)
      return show_ascii(t, anchor, my)
    end
    popup.win, popup.handle = win, handle
  end)
end

-- -----------------------------------------------------------------------------
-- Evaluation + triggers
-- -----------------------------------------------------------------------------
local function eligible(bufnr)
  return cfg.enabled
    and api.nvim_buf_is_valid(bufnr)
    and vim.tbl_contains(cfg.buftypes, vim.bo[bufnr].buftype)
    and not vim.tbl_contains(cfg.exclude_filetypes, vim.bo[bufnr].filetype)
end

local function in_span(span, row0, col1)
  return span ~= nil and span.row == row0 and col1 >= span.s and col1 <= span.e
end

--- Resolve the path at the position; open, keep, or close the popup.
--- Not an image (or not a file) => popup closed, nothing shown.
local function evaluate(ctx)
  if not eligible(ctx.bufnr) then return M.close() end
  local t = find_target(ctx.bufnr, ctx.row0, ctx.col0)
  if not t then return M.close() end
  local key = t.path .. "|" .. t.mtime
  if popup.key == key and popup.win and api.nvim_win_is_valid(popup.win) then
    popup.span = t.span
    return
  end
  M.close()
  popup.key, popup.span, popup.source = key, t.span, ctx.source
  local my = gen
  if sixel_ok() then
    show_sixel(t, ctx.anchor, my)
  else
    show_ascii(t, ctx.anchor, my)
  end
end

local function schedule(fn, ms)
  if not timer then timer = uv.new_timer() end
  timer:stop()
  timer:start(ms, 0, vim.schedule_wrap(fn))
end

local function cursor_ctx()
  local pos = api.nvim_win_get_cursor(0)
  return { bufnr = api.nvim_get_current_buf(), row0 = pos[1] - 1, col0 = pos[2],
           anchor = "cursor", source = "cursor" }
end

local function on_cursor_moved()
  if not cfg.enabled or cfg.trigger == "mouse" then return end
  if api.nvim_win_get_config(0).relative ~= "" then return end
  if popup.win and popup.source == "mouse" then return end
  local pos = api.nvim_win_get_cursor(0)
  if popup.win and in_span(popup.span, pos[1] - 1, pos[2] + 1) then return end
  M.close()
  if vim.fn.mode() ~= "n" then return end
  schedule(function()
    if vim.fn.mode() == "n" then evaluate(cursor_ctx()) end
  end, cfg.delay_ms)
end

local function on_mouse_moved()
  if not cfg.enabled or cfg.trigger == "cursor" then return end
  local m = vim.fn.getmousepos()
  if m.winid == 0 then return end
  if popup.win and m.winid == popup.win then return end
  if m.line == 0 or not api.nvim_win_is_valid(m.winid) then
    if popup.source == "mouse" then M.close() end
    return
  end
  if popup.win and popup.source == "cursor" then return end
  if popup.win and in_span(popup.span, m.line - 1, m.column) then return end
  if popup.source == "mouse" then M.close() end
  local bufnr = api.nvim_win_get_buf(m.winid)
  schedule(function()
    evaluate({ bufnr = bufnr, row0 = m.line - 1, col0 = math.max(0, m.column - 1),
               anchor = "mouse", source = "mouse" })
  end, cfg.delay_ms)
end

-- -----------------------------------------------------------------------------
-- Setup / commands
-- -----------------------------------------------------------------------------
local function set_highlights()
  api.nvim_set_hl(0, cfg.highlights.popup,  { default = true, link = "NormalFloat" })
  api.nvim_set_hl(0, cfg.highlights.border, { default = true, link = "FloatBorder" })
  hl_made = {}
end

--- Configure and activate. Triggers: CursorMoved (debounced by delay_ms) and/or
--- <MouseMove>. Popup closes when the pointer leaves the path, on InsertEnter,
--- mode change, buffer/window leave, scroll, resize and VimLeavePre.
---@param opts table|nil
function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  M._setup_done = true
  set_highlights()
  api.nvim_clear_autocmds({ group = aug })

  api.nvim_create_autocmd("CursorMoved", { group = aug, callback = on_cursor_moved })
  api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave", "WinScrolled", "VimResized" },
    { group = aug, callback = function() M.close() end })
  api.nvim_create_autocmd("ModeChanged", { group = aug, pattern = "n:*",
    callback = function() M.close() end })
  api.nvim_create_autocmd("ColorScheme", { group = aug, callback = set_highlights })
  api.nvim_create_autocmd("VimLeavePre", { group = aug, callback = function()
    M.close()
    if timer then timer:stop(); timer:close(); timer = nil end
  end })

  if cfg.trigger == "mouse" or cfg.trigger == "both" then
    vim.o.mousemoveevent = true
    vim.keymap.set("n", "<MouseMove>", on_mouse_moved,
      { desc = "image-hover: mouse hover", silent = true })
  else
    pcall(vim.keymap.del, "n", "<MouseMove>")
  end
  return M
end

api.nvim_create_user_command("ImageHover", function()
  evaluate(cursor_ctx())
end, { desc = "Show the image under the cursor path now" })

api.nvim_create_user_command("ImageHoverClose", function() M.close() end,
  { desc = "Close the image hover popup" })

api.nvim_create_user_command("ImageHoverToggle", function()
  cfg.enabled = not cfg.enabled
  if not cfg.enabled then M.close() end
  vim.notify("image-hover " .. (cfg.enabled and "enabled" or "disabled"))
end, { desc = "Toggle image hover" })

set_highlights()
api.nvim_create_autocmd("VimEnter", {
  group = aug, once = true,
  callback = function() if not M._setup_done then M.setup({}) end end,
})

return M
