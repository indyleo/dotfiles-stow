-- plugin/comment.lua
-- Minimal self-contained comment toggler for Neovim (single-file)
-- Features:
--  - line vs block selection threshold
--  - unwrap block comments when selecting interior (find enclosing markers)
--  - removes padding lines inserted when block was created
--  - preserves cursor pos
--  - visual-block (rect) support
--  - smarter indent detection and block padding
--  - prefers internal comment_map by default (so C/C++ use // for single lines)
--  - respects vim.bo.commentstring if vim.g.comment_prefer_buffer_commentstring = true
--  - trims CRLF and trailing empty lines
--  - operator-pending mode support (gc{motion})
--  - dot-repeat support
--  - extended language support
--  - setup() configuration function
--  - DEV_MODE for debug notifications

local M = {}

-- ============== CONFIG =================
local DEV_MODE = false -- set true to get vim.notify debug messages
local BLOCK_PADDING = true -- add an empty line after opening / before closing block markers
local DEFAULT_BLOCK_THRESHOLD = 5
local BLOCK_THRESHOLD = vim.g.comment_block_threshold or DEFAULT_BLOCK_THRESHOLD

-- If true, prefer vim.bo.commentstring over internal comment_map
local PREFER_BUFFER_COMMENTSTRING = vim.g.comment_prefer_buffer_commentstring or false

-- =======================================

local comment_map = {
  lua = "-- %s",
  python = "# %s",
  javascript = "// %s",
  typescript = "// %s",
  c = "// %s",
  cpp = "// %s",
  rust = "// %s",
  sh = "# %s",
  bash = "# %s",
  zsh = "# %s",
  html = "<!-- %s -->",
  css = "/* %s */",
  go = "// %s",
  java = "// %s",
  kotlin = "// %s",
  swift = "// %s",
  php = "// %s",
  ruby = "# %s",
  vim = '" %s',
  vimscript = '" %s',
  sql = "-- %s",
  haskell = "-- %s",
  elixir = "# %s",
  yaml = "# %s",
  toml = "# %s",
  jsx = "// %s",
  tsx = "// %s",
  svelte = "// %s",
  vue = "// %s",
  perl = "# %s",
  r = "# %s",
  matlab = "% %s",
  octave = "% %s",
  fortran = "! %s",
  ada = "-- %s",
  lisp = "; %s",
  scheme = "; %s",
  clojure = "; %s",
  erlang = "% %s",
  tex = "% %s",
  plaintex = "% %s",
  arduino = "// %s",
}

local block_map = {
  lua = { prefix = "--[[", suffix = "]]--" },
  javascript = { prefix = "/*", suffix = "*/" },
  typescript = { prefix = "/*", suffix = "*/" },
  c = { prefix = "/*", suffix = "*/" },
  cpp = { prefix = "/*", suffix = "*/" },
  css = { prefix = "/*", suffix = "*/" },
  html = { prefix = "<!--", suffix = "-->" },
  go = { prefix = "/*", suffix = "*/" },
  java = { prefix = "/*", suffix = "*/" },
  kotlin = { prefix = "/*", suffix = "*/" },
  swift = { prefix = "/*", suffix = "*/" },
  php = { prefix = "/*", suffix = "*/" },
  rust = { prefix = "/*", suffix = "*/" },
  svelte = { prefix = "<!--", suffix = "-->" },
  vue = { prefix = "<!--", suffix = "-->" },
  jsx = { prefix = "{/*", suffix = "*/}" },
  tsx = { prefix = "{/*", suffix = "*/}" },
}

-- Pattern cache for performance
local pattern_cache = {}
local function get_escaped_pattern(str)
  if not pattern_cache[str] then
    pattern_cache[str] = vim.pesc(str)
  end
  return pattern_cache[str]
end

-- Last action for dot-repeat support
local last_action = nil

local function debug(msg)
  if DEV_MODE then
    vim.notify("[comment.lua] " .. msg)
  end
end

local function parse_commentstring(cs)
  if not cs or cs == "" then
    return "", ""
  end
  local p, s = cs:match "^(.*)%%s(.*)$"
  p = p and vim.trim(p) or ""
  s = s and vim.trim(s) or ""
  return p, s
end

-- Try treesitter integration if available
local function get_commentstring_from_treesitter()
  local ok, ts_comment = pcall(require, "ts_context_commentstring.internal")
  if ok then
    local cs = ts_comment.calculate_commentstring()
    if cs and cs ~= "" then
      return cs
    end
  end
  return nil
end

-- New: prefer internal comment_map unless user opts in via vim.g
local function get_commentstrings_for_ft(ft)
  -- Try treesitter first if available
  local ts_cs = get_commentstring_from_treesitter()
  if ts_cs and ts_cs:find "%%s" then
    return parse_commentstring(ts_cs)
  end

  if PREFER_BUFFER_COMMENTSTRING then
    local buf_cs = vim.bo.commentstring or ""
    if buf_cs ~= "" and buf_cs:find "%%s" then
      return parse_commentstring(buf_cs)
    end
    local per_line = comment_map[ft]
    if per_line then
      return parse_commentstring(per_line)
    end
    return parse_commentstring "# %s"
  end

  -- default: prefer internal map
  local per_line = comment_map[ft]
  if per_line then
    return parse_commentstring(per_line)
  end

  -- fallback to buffer commentstring if provided
  local buf_cs = vim.bo.commentstring or ""
  if buf_cs ~= "" and buf_cs:find "%%s" then
    return parse_commentstring(buf_cs)
  end

  return parse_commentstring "# %s"
end

local function normalize_and_trim(lines)
  for i = 1, #lines do
    lines[i] = (lines[i] or ""):gsub("\r$", "")
  end
  while #lines > 0 and lines[#lines]:match "^%s*$" do
    table.remove(lines, #lines)
  end
  return lines
end

local function compute_min_indent(lines)
  local min_indent = nil
  for _, l in ipairs(lines) do
    if not l:match "^%s*$" then
      local n = #(l:match "^%s*" or "")
      if not min_indent or n < min_indent then
        min_indent = n
      end
    end
  end
  if not min_indent then
    return ""
  end
  return string.rep(" ", min_indent)
end

-- Improved comment detection
local function is_line_commented(line, prefix, suffix)
  local content = vim.trim(line)
  if content == "" then
    return false
  end

  -- Check if line starts with prefix (after trimming)
  local has_prefix = content:sub(1, #prefix) == prefix

  -- If there's a suffix, check for it too
  if suffix and suffix ~= "" then
    return has_prefix and content:sub(-#suffix) == suffix
  end

  return has_prefix
end

-- Get non-empty lines for better processing
local function get_non_empty_lines(body)
  local non_empty = {}
  for i, line in ipairs(body) do
    if not line:match "^%s*$" then
      table.insert(non_empty, { idx = i, line = line })
    end
  end
  return non_empty
end

-- Search up from start_line-1 for an opening block prefix, and down from end_line+1 for closing suffix.
-- Returns open_idx, close_idx (0-based) if found such that open_idx < start_line and close_idx > end_line.
local function find_enclosing_block(start_line, end_line, block_prefix, block_suffix, search_limit)
  local bufnr = 0
  local top = 0
  local bottom = vim.api.nvim_buf_line_count(bufnr) - 1
  local open_idx, close_idx
  search_limit = search_limit or 1000 -- limit search distance to avoid scanning huge files; configurable if needed

  -- search up
  local up_stop = math.max(top, start_line - search_limit)
  for i = start_line - 1, up_stop, -1 do
    local l = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1] or ""
    if vim.trim(l):match("^" .. get_escaped_pattern(block_prefix)) then
      open_idx = i
      break
    end
  end

  -- search down
  local down_stop = math.min(bottom, end_line + search_limit)
  for j = end_line + 1, down_stop do
    local l = vim.api.nvim_buf_get_lines(0, j, j + 1, false)[1] or ""
    if vim.trim(l):match(get_escaped_pattern(block_suffix) .. "%s*$") then
      close_idx = j
      break
    end
  end

  if open_idx and close_idx and open_idx < start_line and close_idx > end_line then
    return open_idx, close_idx
  end
  return nil, nil
end

-- Unwrap block from open_idx .. close_idx inclusive; remove padding lines if present
local function unwrap_enclosing_block(open_idx, close_idx)
  if not open_idx or not close_idx then
    return false
  end

  local chunk = vim.api.nvim_buf_get_lines(0, open_idx, close_idx + 1, false)
  for i = 1, #chunk do
    chunk[i] = (chunk[i] or ""):gsub("\r$", "")
  end

  -- interior is chunk[2 .. #chunk-1] normally; be defensive:
  local interior = {}
  for i = 2, #chunk - 1 do
    table.insert(interior, chunk[i])
  end

  -- remove BLOCK_PADDING blank lines if set
  if BLOCK_PADDING then
    if #interior > 0 and interior[1]:match "^%s*$" then
      table.remove(interior, 1)
    end
    if #interior > 0 and interior[#interior]:match "^%s*$" then
      table.remove(interior, #interior)
    end
  end

  interior = normalize_and_trim(interior)
  local cur = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(0, open_idx, close_idx + 1, false, interior)
  vim.api.nvim_win_set_cursor(0, cur)
  return true
end

local function body_contains_exact_markers(body, block_prefix, block_suffix)
  for _, l in ipairs(body) do
    local t = vim.trim(l)
    if t == block_prefix or t == block_suffix or t:match("^" .. get_escaped_pattern(block_prefix)) or t:match(get_escaped_pattern(block_suffix) .. "%s*$") then
      return true
    end
  end
  return false
end

local function strip_internal_block_markers(body, block_prefix, block_suffix)
  local out = {}
  local removed = false
  for _, l in ipairs(body) do
    local t = vim.trim(l)
    if t == block_prefix or t == block_suffix then
      removed = true
    else
      table.insert(out, l)
    end
  end
  return out, removed
end

-- Visual-block handler (rectangular)
local function handle_visual_block(sline, scol, eline, ecol, prefix, suffix, uncomment)
  scol = math.max(1, scol)
  ecol = math.max(1, ecol)

  local ctx = vim.api.nvim_buf_get_lines(0, sline, eline + 1, false)
  for i = 1, #ctx do
    local line = ctx[i] or ""
    local before = line:sub(1, scol - 1) or ""
    local middle = line:sub(scol, ecol) or ""
    local after = line:sub(ecol + 1) or ""

    if uncomment then
      local mm = middle
      mm = mm:gsub("^%s*" .. get_escaped_pattern(prefix) .. "%s?", "", 1)
      if suffix ~= "" then
        mm = mm:gsub("%s*" .. get_escaped_pattern(suffix) .. "%s*$", "", 1)
      end
      ctx[i] = before .. mm .. after
    else
      local pfx = prefix
      if pfx ~= "" then
        pfx = pfx .. " "
      end
      local new_middle = pfx .. middle
      if suffix ~= "" then
        new_middle = new_middle .. " " .. suffix
      end
      ctx[i] = before .. new_middle .. after
    end
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(0, sline, eline + 1, false, ctx)
  vim.api.nvim_win_set_cursor(0, cur)
end

-- Core toggle (with error handling)
local function toggle_comment_range(start_line, end_line, mode)
  local ft = vim.bo.filetype
  local block_variant = block_map[ft]
  local body = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
  body = normalize_and_trim(body)

  if #body == 0 then
    return
  end

  local line_prefix, line_suffix = get_commentstrings_for_ft(ft)
  local use_block = (block_variant ~= nil) and (#body >= BLOCK_THRESHOLD)

  if DEV_MODE then
    debug(string.format("ft=%s use_block=%s lines=%d", ft, tostring(use_block), #body))
  end

  if mode == "block_vis" then
    local spos = vim.fn.getpos "'<"
    local epos = vim.fn.getpos "'>"
    local sline = spos[2] - 1
    local scol = spos[3]
    local eline = epos[2] - 1
    local ecol = epos[3]

    if sline > eline then
      sline, eline = eline, sline
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end

    local sample_line = vim.api.nvim_buf_get_lines(0, sline, sline + 1, false)[1] or ""
    local inside = sample_line:sub(scol, scol + #line_prefix) or ""
    local uncomment = inside:match("^%s*" .. get_escaped_pattern(line_prefix))

    handle_visual_block(sline, scol, eline, ecol, line_prefix, line_suffix, uncomment)
    return
  end

  local indent_str = compute_min_indent(body)

  if use_block and block_variant then
    -- First, try to find an enclosing block (search up/down within some reasonable limit)
    local open_idx, close_idx = find_enclosing_block(start_line, end_line, block_variant.prefix, block_variant.suffix, 1000)

    if open_idx and close_idx then
      if unwrap_enclosing_block(open_idx, close_idx) then
        debug "unwrapped enclosing block (found via search)"
        return
      end
    end

    -- If there are exact markers inside selection, strip them to avoid nesting
    if body_contains_exact_markers(body, block_variant.prefix, block_variant.suffix) then
      local stripped, removed = strip_internal_block_markers(body, block_variant.prefix, block_variant.suffix)
      if removed then
        stripped = normalize_and_trim(stripped)
        local cur = vim.api.nvim_win_get_cursor(0)
        vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, stripped)
        vim.api.nvim_win_set_cursor(0, cur)
        debug "stripped internal markers"
        return
      end
    end

    -- No enclosing markers found -> create new block
    local new_lines = {}
    local first_line = indent_str .. block_variant.prefix
    local last_line = indent_str .. block_variant.suffix

    if BLOCK_PADDING then
      table.insert(new_lines, first_line)
      table.insert(new_lines, "")
      for _, l in ipairs(body) do
        table.insert(new_lines, l)
      end
      table.insert(new_lines, "")
      table.insert(new_lines, last_line)
    else
      table.insert(new_lines, first_line)
      for _, l in ipairs(body) do
        table.insert(new_lines, l)
      end
      table.insert(new_lines, last_line)
    end

    local cur = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, new_lines)
    vim.api.nvim_win_set_cursor(0, cur)
    debug "added block comment (fresh)"
    return
  end

  -- LINEWISE mode
  local all_commented = true
  for _, line in ipairs(body) do
    if not line:match "^%s*$" then
      if not is_line_commented(line, line_prefix, line_suffix) then
        all_commented = false
        break
      end
    end
  end

  if all_commented then
    local out = {}
    for _, line in ipairs(body) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      content = content:gsub("^" .. get_escaped_pattern(line_prefix) .. "%s?", "", 1)
      if line_suffix and line_suffix ~= "" then
        content = content:gsub("%s?" .. get_escaped_pattern(line_suffix) .. "%s*$", "", 1)
      end
      table.insert(out, indent .. content)
    end
    local cur = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, out)
    vim.api.nvim_win_set_cursor(0, cur)
    debug "uncommented lines"
    return
  else
    local out = {}
    for _, line in ipairs(body) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      local new = indent .. line_prefix
      if line_prefix ~= "" then
        new = new .. " "
      end
      new = new .. content
      if line_suffix and line_suffix ~= "" then
        new = new .. " " .. line_suffix
      end
      table.insert(out, new)
    end
    local cur = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, out)
    vim.api.nvim_win_set_cursor(0, cur)
    debug "commented lines (linewise)"
    return
  end
end

-- Safe wrapper with error handling
local function safe_toggle_comment_range(start_line, end_line, mode)
  local ok, err = pcall(toggle_comment_range, start_line, end_line, mode)
  if not ok then
    vim.notify("Comment toggle failed: " .. tostring(err), vim.log.levels.ERROR)
    debug("Error: " .. tostring(err))
  end
end

-- Entry points -----------------------------------------------------

local function toggle_comment_normal()
  local l = vim.fn.line "." - 1
  safe_toggle_comment_range(l, l)
  last_action = toggle_comment_normal
end

local function toggle_comment_visual()
  local mode = vim.fn.mode()
  if mode == "\22" or mode == "\026" then
    local spos = vim.fn.getpos "'<"
    local epos = vim.fn.getpos "'>"
    local sline, scol = spos[2] - 1, spos[3]
    local eline, ecol = epos[2] - 1, epos[3]

    if sline > eline then
      sline, eline = eline, sline
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end

    safe_toggle_comment_range(sline, eline, "block_vis")
    last_action = toggle_comment_visual
  else
    local srow = vim.fn.line "'<" - 1
    local erow = vim.fn.line "'>" - 1
    if srow > erow then
      srow, erow = erow, srow
    end
    safe_toggle_comment_range(srow, erow)
    last_action = toggle_comment_visual
  end
end

-- Operator-pending mode support
local function toggle_comment_operator(motion_type)
  motion_type = motion_type or vim.v.event.operator
  local start_line, end_line

  if motion_type == "line" or motion_type == "V" then
    start_line = vim.fn.line "'[" - 1
    end_line = vim.fn.line "']" - 1
  elseif motion_type == "char" or motion_type == "v" then
    start_line = vim.fn.line "'[" - 1
    end_line = vim.fn.line "']" - 1
  elseif motion_type == "block" or motion_type == "\22" then
    start_line = vim.fn.line "'[" - 1
    end_line = vim.fn.line "']" - 1
  else
    return
  end

  safe_toggle_comment_range(start_line, end_line)
  last_action = function()
    toggle_comment_operator(motion_type)
  end
end

-- Operator callback for setting operatorfunc
M.operator_callback = function()
  toggle_comment_operator(vim.v.operator)
end

-- Dot-repeat support
_G._comment_repeat = function()
  if last_action then
    last_action()
  end
end

-- Set operatorfunc helper
local function set_operatorfunc()
  vim.o.operatorfunc = 'v:lua.require("comment").operator_callback'
  return "g@"
end

-- Commands
vim.api.nvim_create_user_command("ToggleComment", function()
  toggle_comment_normal()
end, { desc = "Toggle comment for current line or block" })

vim.api.nvim_create_user_command("ToggleCommentVisual", function()
  toggle_comment_visual()
end, { range = true, desc = "Toggle comment for selection (supports block-visual)" })

-- Configuration function
M.setup = function(opts)
  opts = opts or {}

  if opts.dev_mode ~= nil then
    DEV_MODE = opts.dev_mode
  end

  if opts.block_padding ~= nil then
    BLOCK_PADDING = opts.block_padding
  end

  if opts.block_threshold then
    BLOCK_THRESHOLD = opts.block_threshold
  end

  if opts.prefer_buffer_commentstring ~= nil then
    PREFER_BUFFER_COMMENTSTRING = opts.prefer_buffer_commentstring
  end

  -- Allow users to extend comment maps
  if opts.comment_map then
    comment_map = vim.tbl_extend("force", comment_map, opts.comment_map)
  end

  if opts.block_map then
    block_map = vim.tbl_extend("force", block_map, opts.block_map)
  end

  -- Setup keymaps if provided
  if opts.keymaps ~= false then
    M.setup_keymaps(opts.keymaps or {})
  end
end

-- Keymap setup helper
M.setup_keymaps = function(opts)
  opts = opts or {}
  local normal_key = opts.normal or "gcc"
  local visual_key = opts.visual or "gc"
  local operator_key = opts.operator or "gc"

  vim.keymap.set("n", normal_key, toggle_comment_normal, { desc = "Toggle comment" })
  vim.keymap.set("v", visual_key, toggle_comment_visual, { desc = "Toggle comment (visual)" })

  if operator_key then
    vim.keymap.set("n", operator_key, function()
      vim.o.operatorfunc = 'v:lua.require("comment").operator_callback'
      return "g@"
    end, { expr = true, desc = "Comment operator" })
  end
end

-- Legacy API
M._DEV_MODE = function(val)
  if val == nil then
    return DEV_MODE
  end
  DEV_MODE = not not val
  vim.notify("comment.lua DEV_MODE = " .. tostring(DEV_MODE))
end

-- Export toggle functions for advanced usage
M.toggle_comment_normal = toggle_comment_normal
M.toggle_comment_visual = toggle_comment_visual
M.toggle_comment_operator = toggle_comment_operator

return M
