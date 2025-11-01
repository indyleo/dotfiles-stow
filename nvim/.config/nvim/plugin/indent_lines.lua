-- nvim/plugin/indent-lines.lua

-- Get cache directory for theme
local cache_home = os.getenv "XDG_CACHE_HOME" or os.getenv "HOME" .. "/.cache"
local theme_file = cache_home .. "/theme"

-- Read theme from file
local function read_theme(path)
  local f = io.open(path, "r")
  if f then
    local theme = f:read "*l"
    f:close()
    return theme
  end
  return nil
end

-- Get current theme
local theme = read_theme(theme_file) or "gruvbox"

-- Theme colors
local colors = {
  gruvbox = { "#fb4934", "#fabd2f", "#83a598", "#fe8019", "#b8bb26", "#d3869b", "#8ec07c" },
  nord = { "#BF616A", "#EBCB8B", "#81A1C1", "#D08770", "#A3BE8C", "#B48EAD", "#88C0D0" },
}

-- Set highlight groups
local palette = colors[theme] or colors.gruvbox
for i, color in ipairs(palette) do
  vim.api.nvim_set_hl(0, "IndentLine" .. i, { fg = color })
end

-- Namespace for extmarks
local ns = vim.api.nvim_create_namespace "indent_lines"

-- Draw indent guides
local function draw_indent_lines(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local shiftwidth = vim.bo[buf].shiftwidth
  if shiftwidth == 0 then
    shiftwidth = vim.bo[buf].tabstop
  end

  -- Track indent levels to continue through blank lines
  local prev_indent = 0

  for lnum, line in ipairs(lines) do
    local indent
    local is_blank = line:match "^%s*$"

    if is_blank then
      -- Blank line: use previous indent level
      indent = prev_indent
    else
      -- Non-blank line: calculate indent
      indent = line:match("^%s*"):len()
      prev_indent = indent
    end

    -- Draw each indent guide
    for col = 0, indent - 1, shiftwidth do
      local hl_group = "IndentLine" .. ((col / shiftwidth) % #palette + 1)

      if is_blank then
        -- For blank lines, use virt_text_win_col to position absolutely
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
          virt_text = { { "▎", hl_group } },
          virt_text_win_col = col,
          priority = 1,
        })
      else
        -- For non-blank lines, overlay at the actual column
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, {
          virt_text = { { "▎", hl_group } },
          virt_text_pos = "overlay",
          priority = 1,
        })
      end
    end
  end
end

-- Auto-refresh on buffer changes
local group = vim.api.nvim_create_augroup("IndentLines", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    draw_indent_lines(ev.buf)
  end,
})
