-- =============================================================================
-- mermaid-render.lua  --  Mermaid diagram popup (via mmdr), image-hover style
--
-- Target:    Neovim >= 0.12.6
-- Location:  ~/.config/nvim/plugin/mermaid-render.lua   (single file, no lua/ tree)
--
-- Behaviour (same model as image-hover.lua):
--   * NORMAL mode: when the cursor rests inside a ```mermaid / ```mmd fenced
--     block (or the mouse hovers over it, if enabled), a floating popup shows
--     the rendered diagram.
--   * INSERT mode: nothing is shown; any open popup is closed.
--   * The popup closes when the cursor leaves the block, on InsertEnter, mode
--     change, buffer/window leave, scroll and resize.
--   * Backends: sixel via `_G.sixel_render` (resolved lazily at every call),
--     else ASCII via `chafa --format symbols`, else nothing (one notify_once).
--
-- Dependencies:
--   * `mmdr` (mermaid-rs-renderer)  REQUIRED (source -> PNG, cached).
--   * sixel popup: sixel-render.lua + a sixel encoder (img2sixel|chafa|magick).
--   * ASCII popup: `chafa`.
--   No third-party Lua plugins, no image.nvim.
--
-- Commands: :MermaidRender (show popup for block under cursor now)
--           :MermaidClear  (close popup)   :MermaidAscii (toggle forced ASCII)
--           :MermaidOpen   (open the PNG in xdg-open / $BROWSER)
--
-- Config: require("mermaid-render").setup{ trigger = "both", max_width = 100 }
--   (call from a VimEnter autocmd / after/ file; `_G.mermaid_render` also
--    exists. Zero-config works: setup{} runs on VimEnter.)
--
-- If you use image.nvim's markdown integration, disable it for fences, e.g.
--   require("image").setup({ integrations = { markdown = { enabled = false } } })
-- =============================================================================

if vim.fn.has("nvim-0.12.6") ~= 1 then
  vim.notify("mermaid-render requires Neovim >= 0.12.6 (found " ..
             tostring(vim.version()) .. ")", vim.log.levels.ERROR)
  return
end

local api = vim.api
local uv = vim.uv

local M = {}
package.loaded["mermaid-render"] = M
_G.mermaid_render = M

local ns = api.nvim_create_namespace("mermaid-render")
local aug = api.nvim_create_augroup("MermaidRender", { clear = true })

-- -----------------------------------------------------------------------------
-- Config
-- -----------------------------------------------------------------------------
local defaults = {
  enabled          = true,
  filetypes        = { "markdown" },
  languages        = { "mermaid", "mmd" },
  trigger          = "cursor",   -- "cursor" | "mouse" | "both"
  delay_ms         = 250,
  renderer_cmd     = { "mmdr", "-i", "-", "-e", "png" }, -- "-w/-H/-o" appended
  node_spacing     = nil,
  rank_spacing     = nil,
  cache_dir        = vim.fs.joinpath(vim.fn.stdpath("cache"), "mermaid-render"),
  png_width        = 1600,
  png_height       = 1200,
  max_width        = 80,         -- popup size in cells
  max_height       = 30,
  border           = "rounded",
  force_ascii      = false,
  chafa_cmd        = nil,        -- nil = { "chafa" }
  chafa_colors     = "256",      -- "none" | "2" | "16" | "256" | "full"
  chafa_symbols    = "block+border+space",
  chafa_extra_args = {},
  highlights       = { popup = "MermaidPopup", border = "MermaidPopupBorder" },
}
local cfg = vim.deepcopy(defaults)

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------
local popup = {}          -- { win, handle, key, span = {s, e}, source, png }
local scratch_buf = nil
local gen = 0             -- bumped on every close; stale async results compare to it
local job = nil
local timer = nil
local mem = {}
local hl_made = {}
local failed = {}         -- sha -> true (dedupe mmdr failure notifications)
local scan_cache = {}     -- bufnr -> { tick, blocks }

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
  if cfg.force_ascii then return false end
  local p = provider()
  return p ~= nil and p.supports() == true
end

local function have(cmd)
  return type(cmd) == "table" and cmd[1] ~= nil and vim.fn.exepath(cmd[1]) ~= ""
end
local function chafa_base() return cfg.chafa_cmd or { "chafa" } end

-- -----------------------------------------------------------------------------
-- Block detection (Treesitter, regex fallback)
-- -----------------------------------------------------------------------------
local function lang_set()
  local s = {}
  for _, l in ipairs(cfg.languages) do s[l] = true end
  return s
end

local function make_block(bufnr, sr, end_row)
  local lines = api.nvim_buf_get_lines(bufnr, sr, end_row + 1, false)
  local last = lines[#lines] or ""
  local closed = #lines >= 2 and last:match("^%s*[`~][`~][`~]+%s*$") ~= nil
  local body = vim.list_slice(lines, 2, closed and #lines - 1 or #lines)
  local text = table.concat(body, "\n")
  local ok, out = pcall(vim.text.indent, 0, text) -- dedent fences inside lists
  local source = ok and out or text
  return { start_row = sr, end_row = end_row, source = source, sha = vim.fn.sha256(source) }
end

local function detect_ts(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then return nil end
  local okp, trees = pcall(function() return parser:parse() end)
  if not okp or not trees or not trees[1] then return nil end
  local okq, q = pcall(vim.treesitter.query.parse, "markdown",
    "(fenced_code_block (info_string (language) @lang)) @block")
  if not okq or not q then return nil end
  local idx = {}
  for i, name in ipairs(q.captures) do idx[name] = i end
  local langs, found = lang_set(), {}
  for _, match in q:iter_matches(trees[1]:root(), bufnr, 0, -1, { all = true }) do
    local ln, bn = match[idx.lang], match[idx.block]
    ln, bn = ln and (ln[1] or ln), bn and (bn[1] or bn)
    if ln and bn then
      local lang = vim.treesitter.get_node_text(ln, bufnr)
      if langs[lang] then
        local sr, _, er, ec = bn:range()
        found[#found + 1] = make_block(bufnr, sr, ec == 0 and er - 1 or er)
      end
    end
  end
  return found
end

local function detect_regex(bufnr)
  local langs, found = lang_set(), {}
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local open_row, open_lang
  for i, line in ipairs(lines) do
    if not open_row then
      local info = line:match("^%s*```+%s*([%w_%-]*)%s*$")
      if info then open_row, open_lang = i - 1, info end
    elseif line:match("^%s*```+%s*$") then
      if langs[open_lang] then found[#found + 1] = make_block(bufnr, open_row, i - 1) end
      open_row = nil
    end
  end
  if open_row and langs[open_lang] then
    found[#found + 1] = make_block(bufnr, open_row, #lines - 1)
  end
  return found
end

--- Blocks of `bufnr`, cached per changedtick.
local function get_blocks(bufnr)
  local tick = api.nvim_buf_get_changedtick(bufnr)
  local c = scan_cache[bufnr]
  if c and c.tick == tick then return c.blocks end
  local blocks = detect_ts(bufnr) or detect_regex(bufnr)
  scan_cache[bufnr] = { tick = tick, blocks = blocks }
  return blocks
end

local function block_at(bufnr, row0)
  return vim.iter(get_blocks(bufnr)):find(function(b)
    return row0 >= b.start_row and row0 <= b.end_row
  end)
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

--- Close the popup, clear any sixel placement, cancel in-flight mmdr/chafa.
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
  local name = "MermaidChafa_" .. vim.fn.sha256((fg or "") .. "|" .. (bg or ""))
  if not hl_made[name] then
    api.nvim_set_hl(0, name, { fg = fg, bg = bg, default = true })
    hl_made[name] = true
  end
  return name
end

-- -----------------------------------------------------------------------------
-- mmdr: source -> PNG (cached, cancellable)
-- -----------------------------------------------------------------------------
--- Render `b.source` to a cached PNG. Cache key:
--- sha256(source .. vim.inspect(options)). Stdin is written with :write().
local function render_png(b, my, cb)
  local options = { cfg.renderer_cmd, cfg.png_width, cfg.png_height,
                    cfg.node_spacing, cfg.rank_spacing }
  local key = vim.fn.sha256(b.source .. vim.inspect(options))
  local png = vim.fs.joinpath(cfg.cache_dir, key .. ".png")
  if uv.fs_stat(png) then return cb(png) end

  vim.fn.mkdir(cfg.cache_dir, "p")
  local tmp = vim.fs.joinpath(cfg.cache_dir, key .. ".part.png")
  local cmd = vim.list_extend(vim.deepcopy(cfg.renderer_cmd),
    { "-w", tostring(cfg.png_width), "-H", tostring(cfg.png_height) })
  if cfg.node_spacing then vim.list_extend(cmd, { "--nodeSpacing", tostring(cfg.node_spacing) }) end
  if cfg.rank_spacing then vim.list_extend(cmd, { "--rankSpacing", tostring(cfg.rank_spacing) }) end
  vim.list_extend(cmd, { "-o", tmp })

  local ok, obj = pcall(vim.system, cmd, { stdin = true, text = true },
    vim.schedule_wrap(function(res)
      if my ~= gen then return end
      job = nil
      if res.code == 0 and uv.fs_stat(tmp) then pcall(uv.fs_rename, tmp, png) end
      if uv.fs_stat(png) then return cb(png) end
      if not failed[b.sha] then
        failed[b.sha] = true
        local msg = type(res.stderr) == "string" and vim.trim(res.stderr):match("[^\n]*") or ""
        vim.notify("mermaid-render: mmdr failed" .. (msg ~= "" and (": " .. msg) or ""),
          vim.log.levels.WARN)
      end
    end))
  if not ok then
    vim.notify_once("mermaid-render: could not run `mmdr`: " .. tostring(obj), vim.log.levels.WARN)
    return
  end
  job = obj
  obj:write(b.source)
  obj:write(nil)
end

-- -----------------------------------------------------------------------------
-- Backends
-- -----------------------------------------------------------------------------
--- ASCII backend: `chafa --format symbols` on the mmdr PNG. Shows nothing
--- (plus one notify_once) when chafa is missing.
local function show_ascii(png, anchor, my)
  if not have(chafa_base()) then
    vim.notify_once("mermaid-render: no sixel support and `chafa` not found; " ..
      "diagram popups are disabled.", vim.log.levels.WARN)
    return
  end
  local w, h = cfg.max_width, cfg.max_height
  local st = uv.fs_stat(png)
  local key = table.concat({ png, st and st.mtime.sec or 0, w .. "x" .. h, cfg.chafa_colors,
    cfg.chafa_symbols, vim.inspect(cfg.chafa_extra_args) }, "|")

  local function render(raw)
    local lines = vim.split(raw, "\n", { plain = true })
    while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
    if #lines == 0 then return end
    local texts, rows, width = {}, {}, 1
    for i, l in ipairs(lines) do
      if cfg.chafa_colors == "none" then
        texts[i] = (l:gsub("\27%[[%d;?]*%a", ""))
      else
        local chunks = parse_line(l)
        rows[i] = chunks
        texts[i] = vim.iter(chunks):map(function(c) return c.text end):join("")
      end
      width = math.max(width, vim.fn.strdisplaywidth(texts[i]))
    end
    local buf = set_content(texts)
    for row, chunks in pairs(rows) do
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
    "--size", w .. "x" .. h })
  vim.list_extend(cmd, cfg.chafa_extra_args)
  cmd[#cmd + 1] = png
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

--- Sixel backend: float sized to the image, pixels via sixel_render.place
--- (float = true, 0-based window-relative). Any failure falls back to ASCII.
local function show_sixel(png, ctx, my)
  local wc, hc = cfg.max_width, cfg.max_height
  local p = provider()
  if p and p.measure then
    local a, b = p.measure(png, cfg.max_width, cfg.max_height)
    if a then wc, hc = a, b end
  end
  set_content(vim.fn["repeat"]({ "" }, math.max(1, hc)))
  local win, w, h = open_float(wc, hc, ctx.anchor)
  local handle = P("place", {
    bufnr = ctx.bufnr, winid = win, row = 0, col = 0, path = png,
    id = "mermaid-popup", width_cells = w, height_cells = h, float = true,
  })
  if not handle then
    pcall(api.nvim_win_close, win, true)
    return show_ascii(png, ctx.anchor, my)
  end
  popup.win, popup.handle = win, handle
end

-- -----------------------------------------------------------------------------
-- Evaluation + triggers
-- -----------------------------------------------------------------------------
local function normal_mode()
  -- Include normal-mode submodes (for example operator-pending) while
  -- excluding insert, replace, visual, and command-line modes.
  return vim.fn.mode(1):sub(1, 1) == "n"
end

local function eligible(bufnr)
  return cfg.enabled
    and api.nvim_buf_is_valid(bufnr)
    and vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype)
    and normal_mode()
end

local function in_span(span, row0)
  return span ~= nil and row0 >= span.s and row0 <= span.e
end

--- Show/keep/close the popup for the block at (row0). Not in a block, or not
--- in normal mode => popup closed, nothing shown.
local function evaluate(ctx)
  if not eligible(ctx.bufnr) then return M.close() end
  local b = block_at(ctx.bufnr, ctx.row0)
  if not b then return M.close() end
  if popup.key == b.sha and popup.win and api.nvim_win_is_valid(popup.win) then
    popup.span = { s = b.start_row, e = b.end_row }
    return
  end
  M.close()
  popup.key, popup.span, popup.source = b.sha, { s = b.start_row, e = b.end_row }, ctx.source
  local my = gen
  if vim.fn.exepath(cfg.renderer_cmd[1]) == "" then
    vim.notify_once("mermaid-render: `mmdr` not found on $PATH.", vim.log.levels.WARN)
    return
  end
  render_png(b, my, function(png)
    if my ~= gen then return end
    popup.png = png
    if sixel_ok() then show_sixel(png, ctx, my) else show_ascii(png, ctx.anchor, my) end
  end)
end

local function schedule(fn, ms)
  if not timer then timer = uv.new_timer() end
  timer:stop()
  timer:start(ms, 0, vim.schedule_wrap(fn))
end

local function cursor_ctx()
  local pos = api.nvim_win_get_cursor(0)
  return { bufnr = api.nvim_get_current_buf(), row0 = pos[1] - 1,
           anchor = "cursor", source = "cursor" }
end

local function on_cursor_moved()
  if not cfg.enabled or cfg.trigger == "mouse" then return end
  if api.nvim_win_get_config(0).relative ~= "" then return end
  if popup.win and popup.source == "mouse" then return end
  if popup.win and in_span(popup.span, api.nvim_win_get_cursor(0)[1] - 1) then return end
  M.close()
  if not normal_mode() then return end
  schedule(function() evaluate(cursor_ctx()) end, cfg.delay_ms)
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
  if popup.win and in_span(popup.span, m.line - 1) then return end
  if popup.source == "mouse" then M.close() end
  local bufnr = api.nvim_win_get_buf(m.winid)
  schedule(function()
    evaluate({ bufnr = bufnr, row0 = m.line - 1, anchor = "mouse", source = "mouse" })
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

--- Configure and activate. Normal mode only: CursorMoved (debounced) and/or
--- <MouseMove> open the popup for the fenced block under the pointer; every
--- leave/insert/scroll/resize event closes it.
---@param opts table|nil
function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  M._setup_done = true
  set_highlights()
  api.nvim_clear_autocmds({ group = aug })

  api.nvim_create_autocmd("CursorMoved", { group = aug, callback = on_cursor_moved })
  api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave", "WinScrolled", "VimResized",
                            "TextChanged" },
    { group = aug, callback = function() M.close() end })
  api.nvim_create_autocmd("ModeChanged", { group = aug,
    callback = function()
      if not normal_mode() then M.close() end
    end })
  -- Back in normal mode inside a block: show again after the delay.
  api.nvim_create_autocmd("InsertLeave", { group = aug, callback = function()
    if cfg.trigger ~= "mouse" then schedule(function() evaluate(cursor_ctx()) end, cfg.delay_ms) end
  end })
  api.nvim_create_autocmd("BufUnload", { group = aug, callback = function(ev)
    scan_cache[ev.buf] = nil
  end })
  api.nvim_create_autocmd("ColorScheme", { group = aug, callback = set_highlights })
  api.nvim_create_autocmd("VimLeavePre", { group = aug, callback = function()
    M.close()
    if timer then timer:stop(); timer:close(); timer = nil end
  end })

  if cfg.trigger == "mouse" or cfg.trigger == "both" then
    vim.o.mousemoveevent = true
    vim.keymap.set("n", "<MouseMove>", on_mouse_moved,
      { desc = "mermaid-render: mouse hover", silent = true })
  else
    pcall(vim.keymap.del, "n", "<MouseMove>")
  end
  return M
end

api.nvim_create_user_command("MermaidRender", function() evaluate(cursor_ctx()) end,
  { desc = "Show the mermaid diagram under the cursor now" })
api.nvim_create_user_command("MermaidClear", function() M.close() end,
  { desc = "Close the mermaid popup" })
api.nvim_create_user_command("MermaidAscii", function()
  cfg.force_ascii = not cfg.force_ascii
  M.close()
  vim.notify("mermaid-render: forced ASCII " .. (cfg.force_ascii and "on" or "off"))
end, { desc = "Toggle forced ASCII rendering" })
api.nvim_create_user_command("MermaidOpen", function()
  local bufnr = api.nvim_get_current_buf()
  local b = block_at(bufnr, api.nvim_win_get_cursor(0)[1] - 1)
  if not b then return vim.notify("mermaid-render: no mermaid block under cursor", vim.log.levels.WARN) end
  render_png(b, gen, function(png)
    local opener = vim.env.BROWSER or (vim.fn.has("mac") == 1 and "open" or "xdg-open")
    local ok = pcall(vim.system, { opener, png }, { detach = true })
    if not ok then pcall(vim.ui.open, png) end
  end)
end, { desc = "Open the rendered PNG of the block under cursor" })

set_highlights()
api.nvim_create_autocmd("VimEnter", {
  group = aug, once = true,
  callback = function() if not M._setup_done then M.setup({}) end end,
})

return M
