-- plugin/comment.lua
-- Minimal Comment.nvim-like plugin for Neovim ≥ 0.11.4
-- Supports normal, visual, and visual-block mode (<leader>/)
-- Integrates with ts_context_commentstring and supports block comments

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

-- Safely get commentstring (Treesitter → LSP → filetype → fallback)
local function get_commentstring()
  -- 1️⃣ Treesitter
  local ok, ts_internal = pcall(require, "ts_context_commentstring.internal")
  if ok and ts_internal then
    local cs = ts_internal.calculate_commentstring()
    if cs and cs ~= "" then
      return cs
    end
  end

  -- 2️⃣ LSP’s advertised language
  local clients = vim.lsp.get_clients { bufnr = 0 }
  local lsp_lang = nil
  if #clients > 0 and clients[1].config.filetypes then
    lsp_lang = clients[1].config.filetypes[1]
  end

  -- 3️⃣ Fallbacks
  local ft = vim.bo.filetype
  local cs = M.comment_map[lsp_lang] or M.comment_map[ft] or vim.bo.commentstring or "# %s"
  return cs
end

-- Split commentstring into prefix/suffix (handles line or block style)
local function parse_commentstring(cs)
  local prefix, suffix = cs:match "^(.*)%%s(.*)$"
  prefix = prefix and vim.trim(prefix) or ""
  suffix = suffix and vim.trim(suffix) or ""
  return prefix, suffix
end

-- Toggle comments for a line range
local function toggle_comment(start_line, end_line)
  local cs = get_commentstring()
  local prefix, suffix = parse_commentstring(cs)
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  if #lines == 0 then
    return
  end

  local all_commented = true

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if not trimmed:match("^" .. vim.pesc(prefix)) or (suffix ~= "" and not trimmed:match(vim.pesc(suffix) .. "$")) then
      all_commented = false
      break
    end
  end

  if all_commented then
    -- Uncomment
    for i, line in ipairs(lines) do
      local new = line
      new = new:gsub("^%s*" .. vim.pesc(prefix) .. "%s?", "", 1)
      if suffix ~= "" then
        new = new:gsub("%s?" .. vim.pesc(suffix) .. "%s*$", "", 1)
      end
      lines[i] = new
    end
  else
    -- Comment
    for i, line in ipairs(lines) do
      local indent = line:match "^%s*" or ""
      local new = indent .. prefix
      if prefix ~= "" then
        new = new .. " "
      end
      new = new .. vim.trim(line:sub(#indent + 1))
      if suffix ~= "" then
        new = new .. " " .. suffix
      end
      lines[i] = new
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line, end_line, false, lines)
end

-- Normal mode
local function toggle_line_comment()
  local l = vim.fn.line "." - 1
  toggle_comment(l, l + 1)
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

-- Setup
function M.setup()
  local opts = { noremap = true, silent = true, desc = "Toggle comment (<leader>/)" }

  -- Normal
  vim.keymap.set("n", "<leader>/", toggle_line_comment, opts)

  -- Visual / Visual block
  vim.keymap.set("x", "<leader>/", function()
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "x", false)
    vim.schedule(toggle_visual_comment)
  end, opts)
end

M.setup()
return M
