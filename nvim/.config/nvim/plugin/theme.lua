-- ============================================================================
-- CALAMITY THEME (Self-Contained with Transparent Background)
-- ============================================================================

local c = {
  bg = "#0f0f0f", -- Deep Void (Only used for UI elements that need a solid color)
  bg_alt = "#1a1a1a", -- Dark Charcoal
  bg_high = "#2d2d2d", -- Lighter Charcoal
  fg = "#f9e5c7", -- Auric Silk
  fg_dim = "#e0e0e0", -- Exo Silver

  -- Boss Accents
  red = "#ff003c", -- Profaned Flame
  green = "#73f973", -- Sulphurous Green
  yellow = "#df9d1b", -- Auric Gold
  blue = "#3ec1d3", -- Abyss Teal
  purple = "#b45ef7", -- Cosmic Purple
  orange = "#ffa500", -- Yharon Orange
  blood = "#4c1111", -- Dried Blood
}

local function apply_calamity()
  local hl = vim.api.nvim_set_hl

  -- --- Neovide Specific Settings ---
  if vim.g.neovide then
    vim.g.neovide_background_opacity = 0.85
    vim.g.neovide_cursor_vfx_mode = "railgun"
    vim.g.neovide_cursor_vfx_color = c.red
    -- Neovide handles transparency via its own variable above,
    -- so we set a solid BG here for the GUI.
    hl(0, "Normal", { fg = c.fg, bg = c.bg })
  else
    -- --- Terminal Transparency ---
    -- Setting bg = "NONE" makes the terminal background transparent.
    hl(0, "Normal", { fg = c.fg, bg = "NONE" })
    hl(0, "NormalFloat", { fg = c.fg, bg = "NONE" })
    hl(0, "SignColumn", { bg = "NONE" })
    hl(0, "MsgArea", { bg = "NONE" })
  end

  -- --- UI Highlights ---
  hl(0, "FloatBorder", { fg = c.blue, bg = "NONE" })
  hl(0, "CursorLine", { bg = c.bg_high })
  hl(0, "LineNr", { fg = "#444444" })
  hl(0, "CursorLineNr", { fg = c.yellow, bold = true })
  hl(0, "Visual", { bg = c.blood })
  hl(0, "Search", { fg = c.bg, bg = c.orange })
  hl(0, "IncSearch", { fg = c.bg, bg = c.yellow })
  hl(0, "Pmenu", { fg = c.fg_dim, bg = c.bg_alt })
  hl(0, "PmenuSel", { fg = c.bg, bg = c.blue })
  hl(0, "VertSplit", { fg = c.bg_high, bg = "NONE" })
  hl(0, "StatusLine", { fg = c.fg, bg = c.bg_alt })
  hl(0, "StatusLineNC", { fg = c.blood, bg = c.bg_alt })

  -- --- Syntax Highlights ---
  hl(0, "Comment", { fg = c.blood, italic = true })
  hl(0, "Keyword", { fg = c.red, bold = true })
  hl(0, "Statement", { fg = c.red })
  hl(0, "Function", { fg = c.yellow })
  hl(0, "String", { fg = c.green })
  hl(0, "Constant", { fg = c.orange })
  hl(0, "Number", { fg = c.orange })
  hl(0, "Type", { fg = c.blue })
  hl(0, "Identifier", { fg = c.purple })
  hl(0, "Operator", { fg = c.blue })
  hl(0, "PreProc", { fg = c.red })
  hl(0, "Special", { fg = c.orange })
  hl(0, "Todo", { fg = c.bg, bg = c.yellow, bold = true })

  -- --- Treesitter (Modern Syntax) ---
  hl(0, "@variable", { fg = c.fg })
  hl(0, "@variable.builtin", { fg = c.purple })
  hl(0, "@property", { fg = c.blue })
  hl(0, "@constructor", { fg = c.blue })
  hl(0, "@tag", { fg = c.red })
  hl(0, "@tag.delimiter", { fg = c.blue })
  hl(0, "@text.title", { fg = c.yellow, bold = true })
  hl(0, "@punctuation.bracket", { fg = c.fg_dim })

  -- --- Diagnostics ---
  hl(0, "DiagnosticError", { fg = c.red })
  hl(0, "DiagnosticWarn", { fg = c.yellow })
  hl(0, "DiagnosticInfo", { fg = c.blue })
  hl(0, "DiagnosticHint", { fg = c.green })

  -- --- Terminal Colors ---
  vim.g.terminal_color_0 = c.bg_alt
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.blue
  vim.g.terminal_color_7 = c.fg_dim
end

-- Run immediately
apply_calamity()

-- Maintain transparency on theme reloads
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = apply_calamity,
})
