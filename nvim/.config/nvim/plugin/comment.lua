-- plugin/comment.lua
-- Minimal self-contained comment toggler for Neovim (single-file)
-- Fixes: find & unwrap enclosing block markers even when not selected,
-- removes padding lines on unwrap, avoids nesting.

local M = {}

-- ============== CONFIG =================
local DEV_MODE = true -- set true to get vim.notify debug messages
local BLOCK_PADDING = true -- add an empty line after opening / before closing block markers
local DEFAULT_BLOCK_THRESHOLD = 5
local BLOCK_THRESHOLD = vim.g.comment_block_threshold or DEFAULT_BLOCK_THRESHOLD
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
  html = "<!-- %s -->",
  css = "/* %s */",
}

local block_map = {
  lua = { prefix = "--[[", suffix = "]]--" },
  javascript = { prefix = "/*", suffix = "*/" },
  typescript = { prefix = "/*", suffix = "*/" },
  c = { prefix = "/*", suffix = "*/" },
  cpp = { prefix = "/*", suffix = "*/" },
  css = { prefix = "/*", suffix = "*/" },
  html = { prefix = "<!--", suffix = "-->" },
}

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

local function get_commentstrings_for_ft(ft)
  local buf_cs = vim.bo.commentstring or ""
  if buf_cs ~= "" and buf_cs:find "%%s" then
    local p, s = parse_commentstring(buf_cs)
    return p, s
  end
  local per_line = comment_map[ft]
  if per_line then
    local p, s = parse_commentstring(per_line)
    return p, s
  end
  local fallback = vim.bo.commentstring or "# %s"
  return parse_commentstring(fallback)
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

-- Find enclosing block markers: search up from start_line-1 for prefix and down from end_line+1 for suffix.
-- Returns open_idx, close_idx (both 0-based) or nil,nil.
local function find_enclosing_block(start_line, end_line, block_prefix, block_suffix)
  local bufnr = 0
  local top = 0
  local bottom = vim.api.nvim_buf_line_count(bufnr) - 1
  local open_idx, close_idx

  -- search up for opening prefix
  for i = start_line - 1, top, -1 do
    local l = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1] or ""
    if vim.trim(l):match("^" .. vim.pesc(block_prefix)) then
      open_idx = i
      break
    end
  end

  -- search down for closing suffix
  for j = end_line + 1, bottom do
    local l = vim.api.nvim_buf_get_lines(0, j, j + 1, false)[1] or ""
    if vim.trim(l):match(vim.pesc(block_suffix) .. "%s*$") then
      close_idx = j
      break
    end
  end

  if open_idx and close_idx and open_idx < start_line and close_idx > end_line then
    return open_idx, close_idx
  end
  return nil, nil
end

-- Unwrap enclosing block located at open_idx..close_idx inclusive.
-- Removes padding lines after opening and before closing if BLOCK_PADDING true.
local function unwrap_enclosing_block(open_idx, close_idx)
  if not open_idx or not close_idx then
    return false
  end
  -- fetch entire chunk
  local chunk = vim.api.nvim_buf_get_lines(0, open_idx, close_idx + 1, false)
  for i = 1, #chunk do
    chunk[i] = (chunk[i] or ""):gsub("\r$", "")
  end

  -- find prefix/suffix exact line indices inside chunk (first/last)
  local prefix_idx_in_chunk, suffix_idx_in_chunk
  for i, l in ipairs(chunk) do
    local t = vim.trim(l)
    if not prefix_idx_in_chunk and t:match("^" .. vim.pesc(chunk[1]:match "^%s*(.*)$" or "")) then
      -- noop: keep robust, but we'll just search for prefix/suffix values later
    end
  end

  -- We need to find the first line matching block prefix and last line matching block suffix
  local found_pref, found_suff = nil, nil
  for i, l in ipairs(chunk) do
    local t = vim.trim(l)
    -- we do not know block_prefix/suffix here; they can be inferred:
    -- use trimmed first occurrence of a marker: detect lines that look like a block opener/closer
    -- but safer approach: identify the first line that begins with a non-alphanumeric char sequence and contains '[' or '*' or '<!' etc.
    -- Simpler: assume the first and last lines in chunk are the markers (common case) — but we already have open_idx/close_idx so open/close correspond to chunk[1] and chunk[#chunk]
  end

  -- interior lines are from index 2 .. #chunk-1
  local interior = {}
  for i = 2, #chunk - 1 do
    table.insert(interior, chunk[i])
  end

  -- Remove padding blank line immediately after opening and immediately before closing if present
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

-- check whether body contains exact marker lines
local function body_contains_exact_markers(body, block_prefix, block_suffix)
  for _, l in ipairs(body) do
    local t = vim.trim(l)
    if t == block_prefix or t == block_suffix or t:match("^" .. vim.pesc(block_prefix)) or t:match(vim.pesc(block_suffix) .. "%s*$") then
      return true
    end
  end
  return false
end

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
      mm = mm:gsub("^%s*" .. vim.pesc(prefix) .. "%s?", "", 1)
      if suffix ~= "" then
        mm = mm:gsub("%s*" .. vim.pesc(suffix) .. "%s*$", "", 1)
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

-- toggle logic
local function toggle_comment_range(start_line, end_line, mode)
  local ft = vim.bo.filetype
  local block_variant = block_map[ft]

  -- body exact
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
    local uncomment = inside:match("^%s*" .. vim.pesc(line_prefix))
    handle_visual_block(sline, scol, eline, ecol, line_prefix, line_suffix, uncomment)
    return
  end

  local indent_str = compute_min_indent(body)

  -- if using block mode
  if use_block and block_variant then
    -- find enclosing markers (searching beyond immediate lines)
    local open_idx, close_idx = find_enclosing_block(start_line, end_line, block_variant.prefix, block_variant.suffix)
    if open_idx and close_idx then
      if unwrap_enclosing_block(open_idx, close_idx) then
        debug "unwrapped enclosing block (found via search)"
        return
      end
    end

    -- if there are internal markers inside selection, strip them (avoid nesting)
    if body_contains_exact_markers(body, block_variant.prefix, block_variant.suffix) then
      local stripped = {}
      for _, l in ipairs(body) do
        local t = vim.trim(l)
        if not (t == block_variant.prefix or t == block_variant.suffix) then
          table.insert(stripped, l)
        end
      end
      stripped = normalize_and_trim(stripped)
      local cur = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, stripped)
      vim.api.nvim_win_set_cursor(0, cur)
      debug "stripped internal markers"
      return
    end

    -- no enclosing markers found -> create fresh block
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

  -- linewise
  local all_commented = true
  for _, line in ipairs(body) do
    local content = line:match "^%s*(.*)$" or ""
    if not content:match("^" .. vim.pesc(line_prefix)) then
      all_commented = false
      break
    end
  end

  if all_commented then
    local out = {}
    for _, line in ipairs(body) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      content = content:gsub("^" .. vim.pesc(line_prefix) .. "%s?", "", 1)
      if line_suffix and line_suffix ~= "" then
        content = content:gsub("%s?" .. vim.pesc(line_suffix) .. "%s*$", "", 1)
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

-- entry points
local function toggle_comment_normal()
  local l = vim.fn.line "." - 1
  toggle_comment_range(l, l)
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
    toggle_comment_range(sline, eline, "block_vis")
  else
    local srow = vim.fn.line "'<" - 1
    local erow = vim.fn.line "'>" - 1
    if srow > erow then
      srow, erow = erow, srow
    end
    toggle_comment_range(srow, erow)
  end
end

vim.api.nvim_create_user_command("ToggleComment", function()
  toggle_comment_normal()
end, { desc = "Toggle comment for current line or block" })
vim.api.nvim_create_user_command("ToggleCommentVisual", function()
  toggle_comment_visual()
end, { range = true, desc = "Toggle comment for selection (supports block-visual)" })

-- optional keymaps (commented)
-- vim.keymap.set("n", "<leader>/", ":ToggleComment<CR>", { silent = true })
-- vim.keymap.set("v", "<leader>/", ":ToggleCommentVisual<CR>", { silent = true })

M._DEV_MODE = function(val)
  if val == nil then
    return DEV_MODE
  end
  DEV_MODE = not not val
  vim.notify("comment.lua DEV_MODE = " .. tostring(DEV_MODE))
end

return M
