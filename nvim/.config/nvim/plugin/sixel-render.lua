-- =============================================================================
-- sixel-render.lua  --  dependency-free sixel image provider for Neovim
--
-- Target:    Neovim >= 0.12.6
-- Location:  ~/.config/nvim/plugin/sixel-render.lua   (single file, no lua/ tree)
-- Exposes:   _G.sixel_render  (mirrored to package.loaded["sixel-render"])
--            supports / place / clear / clear_all / refresh / setup
--
-- Dependencies (at least ONE sixel encoder on $PATH):
--   img2sixel (libsixel)  OR  chafa (>= 1.8, `--format sixel`)  OR  ImageMagick
--   (`magick` / `convert`). No Lua libraries, no image.nvim, no nui.
--
-- Known-good sixel terminals: WezTerm, foot, contour, mlterm, mintty, iTerm2,
--   xterm (started with `-ti vt340`), Windows Terminal >= 1.22, Konsole >= 22.04,
--   the alacritty-sixel fork (stock Alacritty has no sixel).
--   NOTE: kitty does NOT implement sixel; it is deliberately not on the list.
--   Use `vim.g.sixel_render_force = true` or setup{ force = true } to override.
--
-- How to verify sixel support in your terminal:
--   * DA1 query: `printf '\e[c'; read -rs -d c r; echo "$r"`; attribute `4`
--     in the reply (e.g. `\e[?65;4;...c`) means sixel graphics are supported.
--   * `infocmp -x $TERM | grep -i sixel`   (some terminfo entries have `Smulx`-like
--     ext caps; `XT`/`sixel` mentions are a hint, not proof).
--   * `tput -T $TERM colors`  (sixel terminals normally report >= 256).
--   * `img2sixel /path/to.png` directly in the shell.
--
-- Usage:
--   _G.sixel_render.place{ bufnr = 0, winid = 0, row = 10, col = 0,
--                          path = "/tmp/x.png", id = "demo", width_cells = 80 }
--   _G.sixel_render.clear_all(0)
--
-- tmux: sixel passes through only if your tmux was built with sixel support
--   (>= 3.4, --enable-sixel). Otherwise set `force = true` at your own risk.
-- =============================================================================

if vim.fn.has("nvim-0.12.6") ~= 1 then
  vim.notify("sixel-render requires Neovim >= 0.12.6 (found " ..
             tostring(vim.version()) .. ")", vim.log.levels.ERROR)
  return
end

if _G.sixel_render and _G.sixel_render._loaded then
  return
end

local api = vim.api
local uv = vim.uv

local M = { _loaded = true }
package.loaded["sixel-render"] = M
_G.sixel_render = M

local ns = api.nvim_create_namespace("sixel-render")
local aug = api.nvim_create_augroup("SixelRender", { clear = true })

-- Exact byte sequences used by this module.
local DCS_CLEAR = "\x1bP0;0;0q\x1b\\"   -- empty sixel DCS: resets stale image slot
local SAVE_CUR  = "\x1b7"               -- DECSC
local REST_CUR  = "\x1b8"               -- DECRC

-- -----------------------------------------------------------------------------
-- Config
-- -----------------------------------------------------------------------------
local defaults = {
  encoder_cmd      = nil,   -- e.g. { "img2sixel", "-w", "800" }; nil = auto-detect
  cache_dir        = vim.fs.joinpath(vim.fn.stdpath("cache"), "sixel-render"),
  max_width_cells  = nil,
  max_height_cells = nil,
  debounce_ms      = 50,
  probe            = false, -- opt-in DA1 probe (best effort, async)
  notify           = vim.notify,
  cell_px          = { 10, 20 }, -- assumed cell size in pixels (w, h)
  force            = false, -- skip terminal detection
  settle_ms        = 40,    -- delay before the post-redraw re-emit
}
local cfg = vim.deepcopy(defaults)

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------
local placements = {}   -- id -> placement record
local jobs = {}         -- cache key -> list of callbacks (coalesced encode jobs)
local encoder = nil     -- resolved encoder { bin, build }
local supported = nil   -- cached supports() result
local debounce_timer = nil
local settle_timer = nil

local KNOWN_TERMS = { "wezterm", "foot", "contour", "mlterm", "mintty",
                      "iterm", "yaft", "windows terminal", "alacritty" }

local ENCODERS = {
  { bin = "img2sixel", build = function(path, wpx, hpx)
      return { "img2sixel", "-w", tostring(wpx), "-h", tostring(hpx), path }
    end },
  { bin = "chafa", build = function(path, _, _, wc, hc)
      return { "chafa", "--format", "sixel", "--size", wc .. "x" .. hc, path }
    end },
  { bin = "magick", build = function(path, wpx, hpx)
      return { "magick", path, "-resize", wpx .. "x" .. hpx .. "!", "sixel:-" }
    end },
  { bin = "convert", build = function(path, wpx, hpx)
      return { "convert", path, "-resize", wpx .. "x" .. hpx .. "!", "sixel:-" }
    end },
}

-- -----------------------------------------------------------------------------
-- Low-level helpers
-- -----------------------------------------------------------------------------

--- The ONLY place terminal bytes are written. Sends raw bytes to the terminal
--- via the stderr channel (falls back to io.stdout).
--- Clear sequence used elsewhere in this file: `\x1bP0;0;0q\x1b\\` (empty DCS).
--- Known-good terminals: see file header.
---@param bytes string
function M._write(bytes)
  if not bytes or bytes == "" then return end
  local ok = pcall(api.nvim_chan_send, vim.v.stderr, bytes)
  if not ok then
    pcall(function()
      io.stdout:write(bytes)
      io.stdout:flush()
    end)
  end
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function write_file(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

--- Read PNG pixel dimensions from the IHDR chunk (no image library needed).
local function png_size(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local head = f:read(24)
  f:close()
  if not head or #head < 24 or head:sub(2, 4) ~= "PNG" then return nil end
  -- LuaJIT has no string.unpack: read the two big-endian uint32s by hand.
  local function be32(i)
    local a, b, c, d = head:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return be32(17), be32(21)
end

--- Fit the image inside (width_cells x height_cells) preserving aspect.
--- Returns wpx, hpx, wcells, hcells.
local function fit(opts, iw, ih)
  local cw, ch = cfg.cell_px[1], cfg.cell_px[2]
  local maxw = math.min(opts.width_cells or math.huge, cfg.max_width_cells or math.huge)
  local maxh = math.min(opts.height_cells or math.huge, cfg.max_height_cells or math.huge)
  local wpx, hpx
  if not iw or not ih then
    wpx = (maxw == math.huge and 80 or maxw) * cw
    hpx = (maxh == math.huge and 25 or maxh) * ch
  else
    if maxw == math.huge and maxh == math.huge then maxw = 80 end
    if maxw ~= math.huge then
      wpx = maxw * cw
      hpx = wpx * ih / iw
      if maxh ~= math.huge and hpx > maxh * ch then
        hpx = maxh * ch
        wpx = hpx * iw / ih
      end
    else
      hpx = maxh * ch
      wpx = hpx * iw / ih
    end
  end
  wpx, hpx = math.max(1, math.floor(wpx)), math.max(1, math.floor(hpx))
  return wpx, hpx, math.max(1, math.ceil(wpx / cw)), math.max(1, math.ceil(hpx / ch))
end

local function resolve_encoder()
  if encoder then return encoder end
  if cfg.encoder_cmd and cfg.encoder_cmd[1] and vim.fn.exepath(cfg.encoder_cmd[1]) ~= "" then
    encoder = {
      bin = cfg.encoder_cmd[1],
      build = function(path)
        local c = vim.deepcopy(cfg.encoder_cmd)
        c[#c + 1] = path
        return c
      end,
    }
    return encoder
  end
  encoder = vim.iter(ENCODERS):find(function(e) return vim.fn.exepath(e.bin) ~= "" end)
  return encoder
end

local function term_looks_sixel()
  if cfg.force or vim.g.sixel_render_force or M._probe_ok then return true end
  local term = (vim.env.TERM or ""):lower()
  local prog = (vim.env.TERM_PROGRAM or ""):lower()
  if vim.env.WT_SESSION or vim.env.KONSOLE_VERSION then return true end
  -- alacritty-sixel fork (stock Alacritty has no sixel; use force = true there at your own risk)
  if vim.env.ALACRITTY_WINDOW_ID or vim.env.ALACRITTY_SOCKET then return true end
  if term:match("^xterm") and vim.env.XTERM_VERSION then return true end
  return vim.iter(KNOWN_TERMS):any(function(n)
    return term:find(n, 1, true) ~= nil or prog:find(n, 1, true) ~= nil
  end)
end

local function detect()
  return term_looks_sixel() and resolve_encoder() ~= nil
end

local function warn_collision()
  if package.loaded["image"] or rawget(_G, "image") then
    vim.notify_once("sixel-render: image.nvim is loaded; two sixel sources will " ..
                    "fight over the same cells. Neither was disabled.", vim.log.levels.WARN)
  end
end

local function redraw(bufnr)
  vim.schedule(function()
    if bufnr ~= 0 and not api.nvim_buf_is_valid(bufnr) then return end
    pcall(api.nvim__redraw, { buf = bufnr, valid = false, flush = true })
  end)
end

--- Overwrite a screen rectangle with spaces and reset the sixel slot, so the
--- terminal drops the pixels; Neovim then repaints via nvim__redraw.
local function erase(r, c, wc, hc)
  local parts = { SAVE_CUR }
  local blank = string.rep(" ", wc)
  for i = 0, hc - 1 do
    parts[#parts + 1] = string.format("\x1b[%d;%dH%s", r + i, c, blank)
  end
  parts[#parts + 1] = REST_CUR
  M._write(DCS_CLEAR .. table.concat(parts))
end

--- Compute the 1-based screen (row, col) where the image's top-left cell goes,
--- or nil when it should not be drawn (off-screen / window gone / buffer swapped).
local function target_pos(p)
  local win = p.winid
  if not api.nvim_win_is_valid(win) then return nil end
  if p.float then
    -- nvim_win_get_position is 0-based; row/col are float-window-relative.
    local pos = api.nvim_win_get_position(win)
    return pos[1] + p.row + 1, pos[2] + p.col + 1
  end
  if api.nvim_win_get_buf(win) ~= p.bufnr then return nil end
  local marks = api.nvim_buf_get_extmarks(p.bufnr, ns, p.ext, p.ext, { details = true })
  if not marks[1] then return nil end
  local lnum = marks[1][2] + 1
  local sp = vim.fn.screenpos(win, lnum, 1)
  if sp.row == 0 then return nil end
  local info = vim.fn.getwininfo(win)[1]
  local rows = 1
  if vim.wo[win].wrap then
    local line = api.nvim_buf_get_lines(p.bufnr, lnum - 1, lnum, false)[1] or ""
    local w = info.width - info.textoff
    if w > 0 then rows = math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / w)) end
  end
  local top = sp.row + rows               -- first reserved virt_line
  local bottom = info.winrow + info.height - 1
  if top + p.hc - 1 > bottom then return nil end
  return top, sp.col + p.col
end

local settle -- forward decl

--- Emit one placement. Sequence: DCS_CLEAR, DECSC, CUP(r;c), <sixel DCS>, DECRC.
local function emit(p, again)
  if not p.bytes then return end
  local r, c = target_pos(p)
  local moved = p.shown and (not r or p.shown.r ~= r or p.shown.c ~= c)
  if moved then
    erase(p.shown.r, p.shown.c, p.wc, p.hc)
    p.shown = nil
    redraw(p.bufnr)
  end
  if not r then return end
  local payload = p.bytes
  if payload:sub(1, 2) ~= "\x1bP" then
    payload = "\x1bPq" .. payload .. "\x1b\\"
  end
  M._write(DCS_CLEAR .. SAVE_CUR .. string.format("\x1b[%d;%dH", r, c) .. payload .. REST_CUR)
  p.shown = { r = r, c = c }
  if not again then
    redraw(p.bufnr)  -- supported async redraw entry point
    p.settle = true
    settle()
  end
end

--- After the forced redraw the terminal may have painted over the image;
--- re-emit once (without another redraw, to avoid loops).
function settle()
  if not settle_timer then settle_timer = uv.new_timer() end
  settle_timer:stop()
  settle_timer:start(cfg.settle_ms, 0, vim.schedule_wrap(function()
    for _, p in pairs(placements) do
      if p.settle then
        p.settle = false
        emit(p, true)
      end
    end
  end))
end

--- Available encoders in priority order (user encoder_cmd alone if set).
local function encoder_chain()
  local first = resolve_encoder()
  local list = { first }
  if not cfg.encoder_cmd then
    for _, e in ipairs(ENCODERS) do
      if e ~= first and vim.fn.exepath(e.bin) ~= "" then list[#list + 1] = e end
    end
  end
  return list
end

--- Async encode (vim.system). One job per (path, mtime, size); duplicates coalesce.
--- Cache: <cache_dir>/<sha256(path .. mtime .. size)>.six
local function encode(path, wpx, hpx, wc, hc, cb)
  local st = uv.fs_stat(path)
  if not st then return cb(nil) end
  local key = vim.fn.sha256(path .. st.mtime.sec .. ":" .. wpx .. "x" .. hpx)
  local out = vim.fs.joinpath(cfg.cache_dir, key .. ".six")
  if uv.fs_stat(out) then
    local bytes = read_file(out)
    if bytes and #bytes > 0 then return cb(bytes) end
  end
  if jobs[key] then
    table.insert(jobs[key], cb)
    return
  end
  local chain = encoder_chain()
  if #chain == 0 then return cb(nil, "no sixel encoder found") end
  jobs[key] = { cb }
  local function finish(bytes, err)
    local cbs = jobs[key] or {}
    jobs[key] = nil
    for _, f in ipairs(cbs) do f(bytes, err) end
  end
  local errs = {}
  -- Try each available encoder in turn; the first that yields a sixel DCS wins.
  local function try(i)
    local enc = chain[i]
    if not enc then return finish(nil, table.concat(errs, "; ")) end
    local ok, err = pcall(vim.system, enc.build(path, wpx, hpx, wc, hc), { text = false },
      vim.schedule_wrap(function(res)
        local so = res.stdout
        if res.code == 0 and so and #so > 0 and so:find("\27P", 1, true) then
          vim.fn.mkdir(cfg.cache_dir, "p")
          write_file(out, so)
          return finish(so)
        end
        local e = type(res.stderr) == "string" and vim.trim(res.stderr):match("[^\n]*") or ""
        errs[#errs + 1] = string.format("%s (exit %s%s)", enc.bin, tostring(res.code),
          e ~= "" and (": " .. e) or (so and #so > 0 and ": output is not sixel" or ""))
        try(i + 1)
      end))
    if not ok then
      errs[#errs + 1] = enc.bin .. ": " .. tostring(err)
      try(i + 1)
    end
  end
  try(1)
end

local function resolve_buf(bufnr)
  if bufnr == nil or bufnr == 0 then return api.nvim_get_current_buf() end
  return bufnr
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

--- Whether sixel output is expected to work: terminal looks sixel-capable
--- (TERM / TERM_PROGRAM list, env hints, or opt-in DA1 probe) AND an encoder
--- binary is on $PATH. Cached at load; recomputed after setup() / probe.
--- Clear sequence used by this module: `\x1bP0;0;0q\x1b\\`.
--- Known-good terminals: WezTerm, foot, contour, mlterm, mintty, iTerm2, xterm.
---@return boolean
function M.supports()
  if supported == nil then supported = detect() end
  return supported
end

--- Place a PNG as sixel. Async: returns a handle immediately; pixels appear
--- once the encode job finishes. Replaces any prior placement with the same id.
--- Non-float: reserves `height_cells` rows below buffer row `row` using extmark
--- virt_lines (no text edits) and draws at the computed screen cell.
--- Float: `row`/`col` are 0-based, window-relative; no extmark is created.
--- Clear sequence: `\x1bP0;0;0q\x1b\\` + space overwrite + nvim__redraw.
--- Returns nil (never errors) when unsupported; one vim.notify_once.
---@param opts table
---@return table|nil handle { id, bufnr, winid, row, col, path }
function M.place(opts)
  if not M.supports() then
    vim.notify_once("sixel-render: sixel unavailable (terminal not recognised or no " ..
      "encoder: img2sixel / chafa / magick). Images will not be drawn.", vim.log.levels.WARN)
    return nil
  end
  if type(opts) ~= "table" or type(opts.path) ~= "string" or type(opts.id) ~= "string" then
    return nil
  end
  warn_collision()
  if not uv.fs_stat(opts.path) then return nil end

  local bufnr = resolve_buf(opts.bufnr)
  local winid = (not opts.winid or opts.winid == 0) and api.nvim_get_current_win() or opts.winid
  if not api.nvim_buf_is_valid(bufnr) or not api.nvim_win_is_valid(winid) then return nil end

  if placements[opts.id] then M.clear(placements[opts.id].handle) end

  local iw, ih = png_size(opts.path)
  local wpx, hpx, wc, hc = fit(opts, iw, ih)
  local handle = { id = opts.id, bufnr = bufnr, winid = winid, row = opts.row,
                   col = opts.col or 0, path = opts.path }
  local p = { handle = handle, bufnr = bufnr, winid = winid, row = opts.row or 0,
              col = opts.col or 0, float = opts.float and true or false,
              path = opts.path, wpx = wpx, hpx = hpx, wc = wc, hc = hc }

  if not p.float then
    local reserve = vim.iter(vim.fn.range(hc)):map(function() return { { "", "Normal" } } end):totable()
    local row0 = math.max(0, math.min((opts.row or 1) - 1, api.nvim_buf_line_count(bufnr) - 1))
    local ok, id = pcall(api.nvim_buf_set_extmark, bufnr, ns, row0, 0, {
      virt_lines = reserve,
      virt_lines_overflow = "scroll",
      hl_mode = "combine",
      priority = 10,
    })
    if not ok then return nil end
    p.ext = id
  end

  placements[opts.id] = p
  encode(opts.path, wpx, hpx, wc, hc, function(bytes, err)
    if placements[opts.id] ~= p then return end
    if not bytes then
      cfg.notify("sixel-render: failed to encode " .. opts.path ..
        (err and err ~= "" and ("\n  " .. err) or ""), vim.log.levels.WARN)
      M.clear(handle)
      return
    end
    p.bytes = bytes
    emit(p)
  end)
  return handle
end

--- Report the (width, height) in cells that `place` will occupy for a PNG when
--- fitted into the given box (same maths as place). Lets consumers size a
--- float window to the image. Returns nil if the PNG header is unreadable.
---@param path string
---@param width_cells integer|nil
---@param height_cells integer|nil
---@return integer|nil wcells, integer|nil hcells
function M.measure(path, width_cells, height_cells)
  local iw, ih = png_size(path)
  if not iw then return nil end
  local _, _, wc, hc = fit({ width_cells = width_cells, height_cells = height_cells }, iw, ih)
  return wc, hc
end

--- Remove one placement: DCS_CLEAR + blank the cells + delete the reservation
--- extmark + nvim__redraw so Neovim repaints. Safe on stale handles.
--- Known-good terminals: see file header.
---@param handle table|nil
function M.clear(handle)
  if not handle then return end
  local p = placements[handle.id]
  if not p or p.handle ~= handle then return end
  placements[handle.id] = nil
  if p.shown then
    erase(p.shown.r, p.shown.c, p.wc, p.hc)
    p.shown = nil
  end
  if p.ext and api.nvim_buf_is_valid(p.bufnr) then
    pcall(api.nvim_buf_del_extmark, p.bufnr, ns, p.ext)
  end
  redraw(p.bufnr)
end

--- Clear every placement belonging to `bufnr` (0 = current; nil = all buffers).
--- Same clear sequence as clear().
---@param bufnr integer|nil
function M.clear_all(bufnr)
  local target = bufnr ~= nil and resolve_buf(bufnr) or nil
  local victims = {}
  for _, p in pairs(placements) do
    if target == nil or p.bufnr == target then victims[#victims + 1] = p.handle end
  end
  for _, h in ipairs(victims) do M.clear(h) end
end

--- Recompute screen positions and re-emit placements for `bufnr`
--- (0 = current, nil = all). Drops placements whose window is gone.
--- Triggered on WinScrolled / VimResized / BufWinEnter / TextChanged (debounced).
---@param bufnr integer|nil
function M.refresh(bufnr)
  local target = bufnr ~= nil and resolve_buf(bufnr) or nil
  local list = {}
  for _, p in pairs(placements) do
    if target == nil or p.bufnr == target then list[#list + 1] = p end
  end
  for _, p in ipairs(list) do
    if not api.nvim_win_is_valid(p.winid) or not api.nvim_buf_is_valid(p.bufnr) then
      M.clear(p.handle)
    else
      emit(p)
    end
  end
end

--- Configure the module. Also available as require("sixel-render").setup.
--- Re-runs detection; with `probe = true` sends DA1 (`\x1b[c`) and looks for
--- attribute 4 in the TermResponse (best effort, async).
---@param opts table|nil
function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  encoder, supported = nil, nil
  if cfg.probe and not M._probing then
    M._probing = true
    api.nvim_create_autocmd("TermResponse", {
      group = aug,
      callback = function(ev)
        local seq = (ev.data and ev.data.sequence) or vim.v.termresponse or ""
        local attrs = seq:match("^\x1b%[%?([%d;]+)c$")
        if not attrs then return end
        if vim.iter(vim.gsplit(attrs, ";", { plain = true })):any(function(a) return a == "4" end) then
          M._probe_ok, supported = true, nil
        end
        return true
      end,
    })
    M._write("\x1b[c")
  end
  M.supports()
  return M
end

-- -----------------------------------------------------------------------------
-- Autocmds
-- -----------------------------------------------------------------------------
local function debounced_refresh()
  if not debounce_timer then debounce_timer = uv.new_timer() end
  debounce_timer:stop()
  debounce_timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(function() M.refresh(nil) end))
end

api.nvim_create_autocmd({ "WinScrolled", "VimResized", "BufWinEnter", "TextChanged",
                          "TextChangedI", "FocusGained" }, {
  group = aug, callback = debounced_refresh,
})

api.nvim_create_autocmd("WinClosed", {
  group = aug,
  callback = function(ev)
    local win = tonumber(ev.match)
    local victims = {}
    for _, p in pairs(placements) do
      if p.winid == win then victims[#victims + 1] = p.handle end
    end
    for _, h in ipairs(victims) do M.clear(h) end
  end,
})

api.nvim_create_autocmd("BufWipeout", {
  group = aug, callback = function(ev) M.clear_all(ev.buf) end,
})

api.nvim_create_autocmd("VimLeavePre", {
  group = aug,
  callback = function()
    M.clear_all(nil)
    if debounce_timer then debounce_timer:stop(); debounce_timer:close(); debounce_timer = nil end
    if settle_timer then settle_timer:stop(); settle_timer:close(); settle_timer = nil end
  end,
})

-- Colorscheme repaint wipes cells: blank everything, then re-emit shortly after.
api.nvim_create_autocmd("ColorScheme", {
  group = aug,
  callback = function()
    for _, p in pairs(placements) do
      if p.shown then
        erase(p.shown.r, p.shown.c, p.wc, p.hc)
        p.shown = nil
      end
      p.settle = true
    end
    settle()
  end,
})

api.nvim_create_autocmd("VimEnter", { group = aug, once = true, callback = warn_collision })

M.supports() -- cache detection at load
return M
