-- plugin/comment.lua
-- Minimal Comment.nvim-like plugin for Neovim ≥ 0.11.4
-- Supports normal, visual, and visual-block mode (<leader>/)
-- Uses line comments for short selections and block comments for long selections

local M = {}

-- Number of lines before switching to block comments
local BLOCK_THRESHOLD = 5

-- Base per-line comment style
M.comment_map = {
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

-- Block comment style for long selections
local block_map = {
  lua = { prefix = "--[[", suffix = "]]--" },
  javascript = { prefix = "/*", suffix = "*/" },
  typescript = { prefix = "/*", suffix = "*/" },
  c = { prefix = "/*", suffix = "*/" },
  cpp = { prefix = "/*", suffix = "*/" },
  css = { prefix = "/*", suffix = "*/" },
  html = { prefix = "<!--", suffix = "-->" },
}

-- Get commentstring
local function get_commentstring()
  local ft = vim.bo.filetype
  return M.comment_map[ft] or vim.bo.commentstring or "# %s"
end

-- Parse a commentstring like "/* %s */" → prefix/suffix
local function parse_commentstring(cs)
  local prefix, suffix = cs:match "^(.*)%%s(.*)$"
  prefix = prefix and vim.trim(prefix) or ""
  suffix = suffix and vim.trim(suffix) or ""
  return prefix, suffix
end

-- Core toggling logic
local function toggle_comment(start_line, end_line)
  local ft = vim.bo.filetype
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  if #lines == 0 then
    return
  end

  local num_lines = #lines
  local first_indent = lines[1]:match "^%s*" or ""

  -- Choose mode: block vs line
  local use_block = num_lines >= BLOCK_THRESHOLD and block_map[ft] ~= nil
  local prefix, suffix

  if use_block then
    prefix, suffix = block_map[ft].prefix, block_map[ft].suffix
  else
    prefix, suffix = parse_commentstring(get_commentstring())
  end

  -- Detect already-commented state
  local all_commented = true
  if not use_block then
    for _, line in ipairs(lines) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      if not content:match("^" .. vim.pesc(prefix)) then
        all_commented = false
        break
      end
    end
  else
    -- Detect surrounding block markers (even if not selected)
    local above = vim.api.nvim_buf_get_lines(0, math.max(0, start_line - 1), start_line, false)[1] or ""
    local below = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""
    if above:match("^%s*" .. vim.pesc(prefix)) and below:match(vim.pesc(suffix) .. "%s*$") then
      all_commented = true
    else
      all_commented = false
    end
  end

  -- Uncomment mode
  if all_commented then
    if use_block then
      -- Remove block delimiters above and below
      local buf_lines = vim.api.nvim_buf_get_lines(0, math.max(0, start_line - 1), end_line + 1, false)
      local new_lines = {}
      for _, l in ipairs(buf_lines) do
        local t = vim.trim(l)
        if not (t:match("^" .. vim.pesc(prefix)) or t:match(vim.pesc(suffix) .. "$")) then
          table.insert(new_lines, l)
        end
      end
      vim.api.nvim_buf_set_lines(0, math.max(0, start_line - 1), end_line + 1, false, new_lines)
    else
      for i, line in ipairs(lines) do
        local indent = line:match "^%s*" or ""
        local content = line:sub(#indent + 1)
        content = content:gsub("^" .. vim.pesc(prefix) .. "%s?", "", 1)
        if suffix ~= "" then
          content = content:gsub("%s?" .. vim.pesc(suffix) .. "%s*$", "", 1)
        end
        lines[i] = indent .. content
      end
      vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
    end
    return
  end

  -- Comment mode
  if use_block then
    table.insert(lines, 1, first_indent .. prefix)
    table.insert(lines, first_indent .. suffix)
  else
    for i, line in ipairs(lines) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      lines[i] = indent .. prefix .. " " .. content .. (suffix ~= "" and (" " .. suffix) or "")
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
end

-- Commands
vim.api.nvim_create_user_command("ToggleComment", function()
  local l = vim.fn.line "." - 1
  toggle_comment(l, l + 1)
end, { desc = "Toggle comment for current line" })

vim.api.nvim_create_user_command("ToggleCommentVisual", function()
  local srow = vim.fn.line "'<" - 1
  local erow = vim.fn.line "'>"
  if srow > erow then
    srow, erow = erow, srow
  end
  toggle_comment(srow, erow)
end, { range = true, desc = "Toggle comment for selection" })

return M
