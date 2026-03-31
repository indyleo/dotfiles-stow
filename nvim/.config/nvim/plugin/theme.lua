-- ============================================================================
-- GRUVBOX THEME (Transparent Background, based on your structure)
-- ============================================================================

local c = {
  bg = "#282828", -- bg0
  bg_alt = "#3c3836", -- bg1
  bg_high = "#504945", -- bg2
  fg = "#ebdbb2", -- fg1
  fg_dim = "#bdae93", -- fg2

  -- Accents (Gruvbox)
  red = "#fb4934",
  green = "#b8bb26",
  yellow = "#fabd2f",
  blue = "#83a598",
  purple = "#d3869b",
  orange = "#fe8019",
  blood = "#7c6f64", -- muted gray (used for comments/visual)
}

local function apply_gruvbox()
  local hl = vim.api.nvim_set_hl

  -- --- Neovide ---
  if vim.g.neovide then
    vim.g.neovide_background_opacity = 0.85
    vim.g.neovide_cursor_vfx_mode = "railgun"
    vim.g.neovide_cursor_vfx_color = c.red
    hl(0, "Normal", { fg = c.fg, bg = c.bg })
  else
    -- --- Transparency ---
    hl(0, "Normal", { fg = c.fg, bg = "NONE" })
    hl(0, "NormalFloat", { fg = c.fg, bg = "NONE" })
    hl(0, "SignColumn", { bg = "NONE" })
    hl(0, "MsgArea", { bg = "NONE" })
  end

  -- --- UI ---
  hl(0, "FloatBorder", { fg = c.blue, bg = "NONE" })
  hl(0, "CursorLine", { bg = c.bg_high })
  hl(0, "LineNr", { fg = "#665c54" })
  hl(0, "CursorLineNr", { fg = c.yellow, bold = true })
  hl(0, "Visual", { bg = c.bg_high })
  hl(0, "Search", { fg = c.bg, bg = c.orange })
  hl(0, "IncSearch", { fg = c.bg, bg = c.yellow })
  hl(0, "Pmenu", { fg = c.fg_dim, bg = c.bg_alt })
  hl(0, "PmenuSel", { fg = c.bg, bg = c.blue })
  hl(0, "VertSplit", { fg = c.bg_high, bg = "NONE" })
  hl(0, "StatusLine", { fg = c.fg, bg = c.bg_alt })
  hl(0, "StatusLineNC", { fg = c.blood, bg = c.bg_alt })

  -- --- Syntax ---
  hl(0, "Comment", { fg = "#928374", italic = true })
  hl(0, "Keyword", { fg = c.red, bold = true })
  hl(0, "Statement", { fg = c.red })
  hl(0, "Function", { fg = c.green })
  hl(0, "String", { fg = c.green })
  hl(0, "Constant", { fg = c.purple })
  hl(0, "Number", { fg = c.purple })
  hl(0, "Type", { fg = c.yellow })
  hl(0, "Identifier", { fg = c.blue })
  hl(0, "Operator", { fg = c.orange })
  hl(0, "PreProc", { fg = c.orange })
  hl(0, "Special", { fg = c.orange })
  hl(0, "Todo", { fg = c.bg, bg = c.yellow, bold = true })

  -- --- Treesitter ---
  hl(0, "@variable", { fg = c.fg })
  hl(0, "@variable.builtin", { fg = c.red })
  hl(0, "@property", { fg = c.blue })
  hl(0, "@constructor", { fg = c.yellow })
  hl(0, "@tag", { fg = c.red })
  hl(0, "@tag.delimiter", { fg = c.blue })
  hl(0, "@text.title", { fg = c.yellow, bold = true })
  hl(0, "@punctuation.bracket", { fg = c.fg_dim })

  -- --- Diagnostics ---
  hl(0, "DiagnosticError", { fg = c.red })
  hl(0, "DiagnosticWarn", { fg = c.yellow })
  hl(0, "DiagnosticInfo", { fg = c.blue })
  hl(0, "DiagnosticHint", { fg = c.green })

  -- --- Terminal ---
  vim.g.terminal_color_0 = c.bg_alt
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.blue
  vim.g.terminal_color_7 = c.fg_dim
end

-- Apply
apply_gruvbox()

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = apply_gruvbox,
})
