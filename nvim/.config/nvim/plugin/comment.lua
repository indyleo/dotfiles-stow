-- plugin/comment.lua
-- Minimal Comment.nvim-like plugin for Neovim ≥ 0.11.4
-- Supports normal, visual, and visual-block mode (<leader>/)
-- Handles line and block comments, integrates with ts_context_commentstring

local M = {}

M.comment_map = {
  lua = "-- %s",
  python = "# %s",
  javascript = "// %s",
  typescript = "// %s",
  c = "/* %s */",
  cpp = "// %s",
  rust = "// %s",
  sh = "# %s",
  html = "<!-- %s -->",
  css = "/* %s */",
}

-- Get commentstring via Treesitter → LSP → filetype → fallback
local function get_commentstring()
  local ok, ts_internal = pcall(require, "ts_context_commentstring.internal")
  if ok and ts_internal then
    local cs = ts_internal.calculate_commentstring()
    if cs and cs ~= "" then
      return cs
    end
  end

  local clients = vim.lsp.get_clients { bufnr = 0 }
  local lsp_lang = nil
  if #clients > 0 and clients[1].config.filetypes then
    lsp_lang = clients[1].config.filetypes[1]
  end

  local ft = vim.bo.filetype
  local cs = M.comment_map[lsp_lang] or M.comment_map[ft] or vim.bo.commentstring or "# %s"
  return cs
end

-- Split commentstring into prefix/suffix (handles line or block)
local function parse_commentstring(cs)
  local prefix, suffix = cs:match "^(.*)%%s(.*)$"
  prefix = prefix and vim.trim(prefix) or ""
  suffix = suffix and vim.trim(suffix) or ""
  return prefix, suffix
end

-- Try to detect if the cursor is inside a block comment via Treesitter
local function detect_block_comment_region()
  local ok, ts = pcall(require, "vim.treesitter")
  if not ok then
    return nil
  end
  local parser = ts.get_parser(0)
  if not parser then
    return nil
  end
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  local root = tree:root()
  local node = root:named_descendant_for_range(vim.fn.line "." - 1, vim.fn.col "." - 1, vim.fn.line "." - 1, vim.fn.col "." - 1)
  while node do
    local type = node:type()
    if type:match "comment" then
      local sr, _, er, _ = node:range()
      return sr, er + 1
    end
    node = node:parent()
  end
  return nil
end

-- Toggle comment for a given range (preserves indent + smart block detection)
local function toggle_comment(start_line, end_line)
  local cs = get_commentstring()
  local prefix, suffix = parse_commentstring(cs)
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  if #lines == 0 then
    return
  end

  local is_block = suffix ~= ""
  local first_indent = lines[1]:match "^%s*" or ""

  -- ✅ Detect if selection is already a wrapped block
  if is_block and #lines >= 2 then
    local first_line = vim.trim(lines[1])
    local last_line = vim.trim(lines[#lines])
    if first_line == prefix and last_line == suffix then
      -- Uncomment block: remove first and last lines
      table.remove(lines, #lines)
      table.remove(lines, 1)
      vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
      return
    end
  end

  -- Check if all lines are commented (per-line style)
  local all_commented = true
  for _, line in ipairs(lines) do
    local indent = line:match "^%s*" or ""
    local content = line:sub(#indent + 1)
    if not content:match("^" .. vim.pesc(prefix)) then
      all_commented = false
      break
    end
  end

  if all_commented then
    -- Uncomment per-line
    for i, line in ipairs(lines) do
      local indent = line:match "^%s*" or ""
      local content = line:sub(#indent + 1)
      content = content:gsub("^" .. vim.pesc(prefix) .. "%s?", "", 1)
      if suffix ~= "" then
        content = content:gsub("%s?" .. vim.pesc(suffix) .. "%s*$", "", 1)
      end
      lines[i] = indent .. content
    end
  else
    if is_block and #lines > 1 then
      -- Comment as wrapped block
      table.insert(lines, 1, first_indent .. prefix)
      table.insert(lines, first_indent .. suffix)
    else
      -- Single-line or line-comment mode
      for i, line in ipairs(lines) do
        local indent = line:match "^%s*" or ""
        local content = line:sub(#indent + 1)
        local new = indent .. prefix
        if prefix ~= "" then
          new = new .. " "
        end
        new = new .. content
        if suffix ~= "" then
          new = new .. " " .. suffix
        end
        lines[i] = new
      end
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
end

-- Toggle entire block comment if inside one
local function toggle_block_comment_if_inside()
  local sr, er = detect_block_comment_region()
  if sr and er then
    toggle_comment(sr, er)
    return true
  end
  return false
end

-- Normal mode
local function toggle_line_comment()
  if not toggle_block_comment_if_inside() then
    local l = vim.fn.line "." - 1
    toggle_comment(l, l + 1)
  end
end

-- Visual & Visual Block
local function toggle_visual_comment()
  local srow = vim.fn.line "'<" - 1
  local erow = vim.fn.line "'>"
  if srow > erow then
    srow, erow = erow, srow
  end
  toggle_comment(srow, erow)
end

-- Expose commands instead of keymaps
function M.setup()
  -- Normal toggle command
  vim.api.nvim_create_user_command("ToggleComment", function()
    if not toggle_block_comment_if_inside() then
      local l = vim.fn.line "." - 1
      toggle_comment(l, l + 1)
    end
  end, { desc = "Toggle comment for current line or block" })

  -- Visual mode toggle command
  vim.api.nvim_create_user_command("ToggleCommentVisual", function()
    local srow = vim.fn.line "'<" - 1
    local erow = vim.fn.line "'>"
    if srow > erow then
      srow, erow = erow, srow
    end
    toggle_comment(srow, erow)
  end, { range = true, desc = "Toggle comment for selected lines" })
end

M.setup()
return M
