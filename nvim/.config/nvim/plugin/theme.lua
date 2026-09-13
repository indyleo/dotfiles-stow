-- ============================================================================
-- GRUVBOX THEME (Transparent Background)
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
  aqua = "#8ec07c",
  gray = "#928374",
  blood = "#7c6f64", -- muted gray (used for comments/visual)
}

local function apply_gruvbox()
  local hl = vim.api.nvim_set_hl

  -- ==========================================================================
  -- Neovide / transparency
  -- ==========================================================================
  if vim.g.neovide then
    vim.g.neovide_background_opacity = 0.85
    vim.g.neovide_normal_opacity = 0.85
    vim.g.neovide_cursor_vfx_mode = "railgun"
    vim.g.neovide_cursor_vfx_color = c.red
    vim.g.neovide_cursor_animation_length = 0.08
    vim.g.neovide_cursor_trail_size = 0.5
    vim.g.neovide_floating_shadow = false
    vim.g.neovide_floating_blur_amount_x = 2.0
    vim.g.neovide_floating_blur_amount_y = 2.0
    hl(0, "Normal", { fg = c.fg, bg = c.bg })
  else
    hl(0, "Normal", { fg = c.fg, bg = "NONE" })
    hl(0, "NormalFloat", { fg = c.fg, bg = "NONE" })
    hl(0, "NormalNC", { fg = c.fg_dim, bg = "NONE" })
    hl(0, "SignColumn", { bg = "NONE" })
    hl(0, "MsgArea", { bg = "NONE" })
    hl(0, "EndOfBuffer", { fg = c.bg, bg = "NONE" })
  end

  -- ==========================================================================
  -- Core UI
  -- ==========================================================================
  hl(0, "FloatBorder", { fg = c.blue, bg = "NONE" })
  hl(0, "FloatTitle", { fg = c.yellow, bold = true, bg = "NONE" })
  hl(0, "CursorLine", { bg = c.bg_high })
  hl(0, "CursorColumn", { bg = c.bg_high })
  hl(0, "ColorColumn", { bg = c.bg_alt })
  hl(0, "LineNr", { fg = "#665c54" })
  hl(0, "CursorLineNr", { fg = c.yellow, bold = true })
  hl(0, "Visual", { bg = c.bg_high })
  hl(0, "VisualNOS", { bg = c.bg_high })
  hl(0, "Search", { fg = c.bg, bg = c.orange })
  hl(0, "IncSearch", { fg = c.bg, bg = c.yellow })
  hl(0, "CurSearch", { fg = c.bg, bg = c.yellow })
  hl(0, "Pmenu", { fg = c.fg_dim, bg = c.bg_alt })
  hl(0, "PmenuSel", { fg = c.bg, bg = c.blue })
  hl(0, "PmenuSbar", { bg = c.bg_alt })
  hl(0, "PmenuThumb", { bg = c.bg_high })
  hl(0, "WinSeparator", { fg = c.bg_high, bg = "NONE" })
  hl(0, "VertSplit", { fg = c.bg_high, bg = "NONE" })
  hl(0, "StatusLine", { fg = c.fg, bg = c.bg_alt })
  hl(0, "StatusLineNC", { fg = c.blood, bg = c.bg_alt })
  hl(0, "TabLine", { fg = c.fg_dim, bg = c.bg_alt })
  hl(0, "TabLineSel", { fg = c.yellow, bg = c.bg_high, bold = true })
  hl(0, "TabLineFill", { bg = "NONE" })
  hl(0, "MatchParen", { fg = c.orange, bold = true, underline = true })
  hl(0, "Directory", { fg = c.blue })
  hl(0, "Title", { fg = c.yellow, bold = true })
  hl(0, "NonText", { fg = c.bg_high })
  hl(0, "Whitespace", { fg = c.bg_high })
  hl(0, "Folded", { fg = c.fg_dim, bg = c.bg_alt })
  hl(0, "FoldColumn", { fg = c.blood, bg = "NONE" })
  hl(0, "WildMenu", { fg = c.bg, bg = c.blue })
  hl(0, "ModeMsg", { fg = c.yellow })
  hl(0, "MoreMsg", { fg = c.green })
  hl(0, "Question", { fg = c.green })
  hl(0, "WinBar", { fg = c.fg_dim, bg = "NONE" })
  hl(0, "WinBarNC", { fg = c.blood, bg = "NONE" })

  -- ==========================================================================
  -- Syntax (base groups)
  -- ==========================================================================
  hl(0, "Comment", { fg = c.gray, italic = true })
  hl(0, "Keyword", { fg = c.red, bold = true })
  hl(0, "Statement", { fg = c.red })
  hl(0, "Conditional", { fg = c.red })
  hl(0, "Repeat", { fg = c.red })
  hl(0, "Label", { fg = c.red })
  hl(0, "Exception", { fg = c.red })
  hl(0, "Function", { fg = c.green })
  hl(0, "String", { fg = c.green })
  hl(0, "Character", { fg = c.green })
  hl(0, "Constant", { fg = c.purple })
  hl(0, "Number", { fg = c.purple })
  hl(0, "Boolean", { fg = c.purple })
  hl(0, "Float", { fg = c.purple })
  hl(0, "Type", { fg = c.yellow })
  hl(0, "StorageClass", { fg = c.yellow })
  hl(0, "Structure", { fg = c.yellow })
  hl(0, "Typedef", { fg = c.yellow })
  hl(0, "Identifier", { fg = c.blue })
  hl(0, "Operator", { fg = c.orange })
  hl(0, "PreProc", { fg = c.orange })
  hl(0, "Include", { fg = c.orange })
  hl(0, "Define", { fg = c.orange })
  hl(0, "Macro", { fg = c.orange })
  hl(0, "Special", { fg = c.orange })
  hl(0, "SpecialChar", { fg = c.orange })
  hl(0, "Delimiter", { fg = c.fg_dim })
  hl(0, "Underlined", { fg = c.blue, underline = true })
  hl(0, "Error", { fg = c.red, bold = true })
  hl(0, "Todo", { fg = c.bg, bg = c.yellow, bold = true })

  -- ==========================================================================
  -- Treesitter
  -- ==========================================================================
  hl(0, "@variable", { fg = c.fg })
  hl(0, "@variable.builtin", { fg = c.red })
  hl(0, "@variable.parameter", { fg = c.fg, italic = true })
  hl(0, "@variable.member", { fg = c.blue })
  hl(0, "@property", { fg = c.blue })
  hl(0, "@field", { fg = c.blue })
  hl(0, "@constructor", { fg = c.yellow })
  hl(0, "@constant", { fg = c.purple })
  hl(0, "@constant.builtin", { fg = c.purple, bold = true })
  hl(0, "@string.escape", { fg = c.orange })
  hl(0, "@tag", { fg = c.red })
  hl(0, "@tag.attribute", { fg = c.yellow })
  hl(0, "@tag.delimiter", { fg = c.blue })
  hl(0, "@text.title", { fg = c.yellow, bold = true })
  hl(0, "@text.literal", { fg = c.green })
  hl(0, "@text.uri", { fg = c.blue, underline = true })
  hl(0, "@punctuation.bracket", { fg = c.fg_dim })
  hl(0, "@punctuation.delimiter", { fg = c.fg_dim })
  hl(0, "@punctuation.special", { fg = c.orange })
  hl(0, "@keyword.function", { fg = c.red, bold = true })
  hl(0, "@keyword.return", { fg = c.red, bold = true })
  hl(0, "@function.builtin", { fg = c.green, italic = true })
  hl(0, "@function.call", { fg = c.green })
  hl(0, "@method", { fg = c.green })
  hl(0, "@method.call", { fg = c.green })
  hl(0, "@comment", { fg = c.gray, italic = true })

  -- ==========================================================================
  -- LSP
  -- ==========================================================================
  hl(0, "LspReferenceText", { bg = c.bg_high })
  hl(0, "LspReferenceRead", { bg = c.bg_high })
  hl(0, "LspReferenceWrite", { bg = c.bg_high, underline = true })
  hl(0, "LspSignatureActiveParameter", { fg = c.yellow, bold = true })
  hl(0, "LspCodeLens", { fg = c.blood, italic = true })
  hl(0, "LspInlayHint", { fg = c.blood, bg = c.bg_alt, italic = true })

  hl(0, "DiagnosticError", { fg = c.red })
  hl(0, "DiagnosticWarn", { fg = c.yellow })
  hl(0, "DiagnosticInfo", { fg = c.blue })
  hl(0, "DiagnosticHint", { fg = c.green })
  hl(0, "DiagnosticOk", { fg = c.green })
  hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = c.red })
  hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
  hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = c.blue })
  hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = c.green })
  hl(0, "DiagnosticVirtualTextError", { fg = c.red, bg = "NONE" })
  hl(0, "DiagnosticVirtualTextWarn", { fg = c.yellow, bg = "NONE" })
  hl(0, "DiagnosticVirtualTextInfo", { fg = c.blue, bg = "NONE" })
  hl(0, "DiagnosticVirtualTextHint", { fg = c.green, bg = "NONE" })
  hl(0, "DiagnosticFloatingError", { fg = c.red })
  hl(0, "DiagnosticFloatingWarn", { fg = c.yellow })
  hl(0, "DiagnosticFloatingInfo", { fg = c.blue })
  hl(0, "DiagnosticFloatingHint", { fg = c.green })
  hl(0, "DiagnosticSignError", { fg = c.red })
  hl(0, "DiagnosticSignWarn", { fg = c.yellow })
  hl(0, "DiagnosticSignInfo", { fg = c.blue })
  hl(0, "DiagnosticSignHint", { fg = c.green })

  -- LSP semantic tokens (only kick in if server provides them; harmless otherwise)
  hl(0, "@lsp.type.class", { fg = c.yellow })
  hl(0, "@lsp.type.interface", { fg = c.yellow })
  hl(0, "@lsp.type.enum", { fg = c.yellow })
  hl(0, "@lsp.type.enumMember", { fg = c.purple })
  hl(0, "@lsp.type.parameter", { fg = c.fg, italic = true })
  hl(0, "@lsp.type.property", { fg = c.blue })
  hl(0, "@lsp.type.variable", { fg = c.fg })
  hl(0, "@lsp.type.namespace", { fg = c.aqua })
  hl(0, "@lsp.mod.readonly", { italic = true })

  -- ==========================================================================
  -- which-key
  -- ==========================================================================
  hl(0, "WhichKey", { fg = c.blue, bold = true })
  hl(0, "WhichKeyGroup", { fg = c.orange })
  hl(0, "WhichKeyDesc", { fg = c.fg })
  hl(0, "WhichKeySeparator", { fg = c.blood })
  hl(0, "WhichKeyFloat", { bg = "NONE" })
  hl(0, "WhichKeyBorder", { fg = c.blue, bg = "NONE" })
  hl(0, "WhichKeyValue", { fg = c.fg_dim })

  -- ==========================================================================
  -- Telescope
  -- ==========================================================================
  hl(0, "TelescopeNormal", { fg = c.fg, bg = "NONE" })
  hl(0, "TelescopeBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "TelescopePromptNormal", { fg = c.fg, bg = c.bg_alt })
  hl(0, "TelescopePromptBorder", { fg = c.blue, bg = c.bg_alt })
  hl(0, "TelescopePromptTitle", { fg = c.bg, bg = c.blue, bold = true })
  hl(0, "TelescopeResultsBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "TelescopeResultsTitle", { fg = c.bg, bg = c.green, bold = true })
  hl(0, "TelescopePreviewBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "TelescopePreviewTitle", { fg = c.bg, bg = c.yellow, bold = true })
  hl(0, "TelescopeSelection", { bg = c.bg_high, fg = c.fg })
  hl(0, "TelescopeSelectionCaret", { fg = c.red })
  hl(0, "TelescopeMatching", { fg = c.yellow, bold = true })
  hl(0, "TelescopePromptPrefix", { fg = c.red })

  -- ==========================================================================
  -- fzf-lua
  -- ==========================================================================
  hl(0, "FzfLuaNormal", { fg = c.fg, bg = "NONE" })
  hl(0, "FzfLuaBorder", { fg = c.blue, bg = "NONE" })
  hl(0, "FzfLuaTitle", { fg = c.bg, bg = c.blue, bold = true })
  hl(0, "FzfLuaPreviewNormal", { fg = c.fg, bg = "NONE" })
  hl(0, "FzfLuaPreviewBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "FzfLuaPreviewTitle", { fg = c.bg, bg = c.yellow, bold = true })
  hl(0, "FzfLuaCursor", { fg = c.bg, bg = c.fg })
  hl(0, "FzfLuaCursorLine", { bg = c.bg_high })
  hl(0, "FzfLuaCursorLineNr", { fg = c.yellow, bold = true })
  hl(0, "FzfLuaScrollBorderEmpty", { fg = c.bg_high })
  hl(0, "FzfLuaScrollBorderFull", { fg = c.blue })
  hl(0, "FzfLuaHeaderBind", { fg = c.orange })
  hl(0, "FzfLuaHeaderText", { fg = c.fg_dim })
  hl(0, "FzfLuaPathColNr", { fg = c.purple })
  hl(0, "FzfLuaPathLineNr", { fg = c.blood })
  hl(0, "FzfLuaBufName", { fg = c.blue })
  hl(0, "FzfLuaBufNr", { fg = c.purple })
  hl(0, "FzfLuaBufFlagCur", { fg = c.yellow })
  hl(0, "FzfLuaBufFlagAlt", { fg = c.orange })
  hl(0, "FzfLuaTabTitle", { fg = c.yellow, bold = true })
  hl(0, "FzfLuaTabMarker", { fg = c.red })
  hl(0, "FzfLuaLiveSym", { fg = c.yellow, bold = true })
  hl(0, "FzfLuaFzfMatch", { fg = c.yellow, bold = true })
  hl(0, "FzfLuaFzfPointer", { fg = c.red })
  hl(0, "FzfLuaFzfMarker", { fg = c.green })

  -- ==========================================================================
  -- Gitsigns
  -- ==========================================================================
  hl(0, "GitSignsAdd", { fg = c.green })
  hl(0, "GitSignsChange", { fg = c.yellow })
  hl(0, "GitSignsDelete", { fg = c.red })
  hl(0, "GitSignsChangedelete", { fg = c.orange })
  hl(0, "GitSignsTopdelete", { fg = c.red })
  hl(0, "GitSignsCurrentLineBlame", { fg = c.blood, italic = true })
  hl(0, "GitSignsAddPreview", { fg = c.green, bg = c.bg_alt })
  hl(0, "GitSignsDeletePreview", { fg = c.red, bg = c.bg_alt })

  -- ==========================================================================
  -- Completion (nvim-cmp / blink.cmp)
  -- ==========================================================================
  hl(0, "CmpItemAbbrMatch", { fg = c.yellow, bold = true })
  hl(0, "CmpItemAbbrMatchFuzzy", { fg = c.yellow })
  hl(0, "CmpItemAbbrDeprecated", { fg = c.blood, strikethrough = true })
  hl(0, "CmpItemKindFunction", { fg = c.green })
  hl(0, "CmpItemKindMethod", { fg = c.green })
  hl(0, "CmpItemKindVariable", { fg = c.blue })
  hl(0, "CmpItemKindField", { fg = c.blue })
  hl(0, "CmpItemKindProperty", { fg = c.blue })
  hl(0, "CmpItemKindKeyword", { fg = c.red })
  hl(0, "CmpItemKindClass", { fg = c.yellow })
  hl(0, "CmpItemKindInterface", { fg = c.yellow })
  hl(0, "CmpItemKindModule", { fg = c.aqua })
  hl(0, "CmpItemKindSnippet", { fg = c.purple })
  hl(0, "CmpItemKindConstant", { fg = c.purple })
  hl(0, "CmpItemKindText", { fg = c.fg_dim })
  hl(0, "CmpItemKindFile", { fg = c.fg_dim })
  hl(0, "CmpBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "CmpDocBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "BlinkCmpMenuBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "BlinkCmpDocBorder", { fg = c.bg_high, bg = "NONE" })
  hl(0, "BlinkCmpLabelMatch", { fg = c.yellow, bold = true })

  -- ==========================================================================
  -- nvim-tree / neo-tree
  -- ==========================================================================
  hl(0, "NvimTreeNormal", { fg = c.fg, bg = "NONE" })
  hl(0, "NvimTreeFolderIcon", { fg = c.blue })
  hl(0, "NvimTreeFolderName", { fg = c.blue })
  hl(0, "NvimTreeOpenedFolderName", { fg = c.blue, bold = true })
  hl(0, "NvimTreeRootFolder", { fg = c.orange, bold = true })
  hl(0, "NvimTreeGitDirty", { fg = c.yellow })
  hl(0, "NvimTreeGitNew", { fg = c.green })
  hl(0, "NvimTreeGitDeleted", { fg = c.red })
  hl(0, "NvimTreeIndentMarker", { fg = c.bg_high })
  hl(0, "NvimTreeWinSeparator", { fg = c.bg_high, bg = "NONE" })
  hl(0, "NvimTreeSpecialFile", { fg = c.purple, underline = true })
  hl(0, "NvimTreeExecFile", { fg = c.green })

  hl(0, "NeoTreeNormal", { fg = c.fg, bg = "NONE" })
  hl(0, "NeoTreeDirectoryIcon", { fg = c.blue })
  hl(0, "NeoTreeDirectoryName", { fg = c.blue })
  hl(0, "NeoTreeRootName", { fg = c.orange, bold = true })
  hl(0, "NeoTreeGitAdded", { fg = c.green })
  hl(0, "NeoTreeGitModified", { fg = c.yellow })
  hl(0, "NeoTreeGitDeleted", { fg = c.red })
  hl(0, "NeoTreeIndentMarker", { fg = c.bg_high })
  hl(0, "NeoTreeWinSeparator", { fg = c.bg_high, bg = "NONE" })

  -- ==========================================================================
  -- lualine (pass as a custom theme table in setup, not global hl)
  -- ==========================================================================
  -- Example: require("lualine").setup({ options = { theme = gruvbox_lualine_theme } })
  -- kept here for reference/export if you want it:
  -- local lualine_theme = {
  --   normal = { a = { fg = c.bg, bg = c.blue, gui = "bold" }, b = { fg = c.fg, bg = c.bg_alt }, c = { fg = c.fg_dim, bg = "NONE" } },
  --   insert = { a = { fg = c.bg, bg = c.green, gui = "bold" } },
  --   visual = { a = { fg = c.bg, bg = c.purple, gui = "bold" } },
  --   replace = { a = { fg = c.bg, bg = c.red, gui = "bold" } },
  --   command = { a = { fg = c.bg, bg = c.yellow, gui = "bold" } },
  --   inactive = { a = { fg = c.blood, bg = c.bg_alt }, b = { fg = c.blood, bg = c.bg_alt }, c = { fg = c.blood, bg = "NONE" } },
  -- }

  -- ==========================================================================
  -- bufferline
  -- ==========================================================================
  hl(0, "BufferLineFill", { bg = "NONE" })
  hl(0, "BufferLineBackground", { fg = c.fg_dim, bg = "NONE" })
  hl(0, "BufferLineBufferSelected", { fg = c.yellow, bg = c.bg_high, bold = true })
  hl(0, "BufferLineIndicatorSelected", { fg = c.yellow })
  hl(0, "BufferLineSeparator", { fg = c.bg, bg = "NONE" })
  hl(0, "BufferLineModified", { fg = c.orange })
  hl(0, "BufferLineModifiedSelected", { fg = c.orange })
  hl(0, "BufferLineCloseButton", { fg = c.fg_dim })
  hl(0, "BufferLineCloseButtonSelected", { fg = c.red })

  -- ==========================================================================
  -- indent-blankline (ibl)
  -- ==========================================================================
  hl(0, "IblIndent", { fg = c.bg_high })
  hl(0, "IblScope", { fg = c.orange })
  hl(0, "IblWhitespace", { fg = c.bg_high })

  -- ==========================================================================
  -- Trouble
  -- ==========================================================================
  hl(0, "TroubleNormal", { bg = "NONE" })
  hl(0, "TroubleText", { fg = c.fg })
  hl(0, "TroubleCount", { fg = c.yellow })
  hl(0, "TroubleFile", { fg = c.blue })
  hl(0, "TroubleIndent", { fg = c.bg_high })
  hl(0, "TroubleFoldIcon", { fg = c.orange })
  hl(0, "TroubleLocation", { fg = c.blood })

  -- ==========================================================================
  -- noice / notify
  -- ==========================================================================
  hl(0, "NotifyERRORBorder", { fg = c.red })
  hl(0, "NotifyWARNBorder", { fg = c.yellow })
  hl(0, "NotifyINFOBorder", { fg = c.blue })
  hl(0, "NotifyDEBUGBorder", { fg = c.blood })
  hl(0, "NotifyTRACEBorder", { fg = c.purple })
  hl(0, "NotifyERRORIcon", { fg = c.red })
  hl(0, "NotifyWARNIcon", { fg = c.yellow })
  hl(0, "NotifyINFOIcon", { fg = c.blue })
  hl(0, "NotifyERRORTitle", { fg = c.red })
  hl(0, "NotifyWARNTitle", { fg = c.yellow })
  hl(0, "NotifyINFOTitle", { fg = c.blue })
  hl(0, "NoiceCmdlinePopupBorder", { fg = c.blue })
  hl(0, "NoiceCmdlineIcon", { fg = c.yellow })
  hl(0, "NoiceCmdlinePopupTitle", { fg = c.yellow, bold = true })

  -- ==========================================================================
  -- Mini.icons / mini.statusline (if used)
  -- ==========================================================================
  hl(0, "MiniStatuslineModeNormal", { fg = c.bg, bg = c.blue, bold = true })
  hl(0, "MiniStatuslineModeInsert", { fg = c.bg, bg = c.green, bold = true })
  hl(0, "MiniStatuslineModeVisual", { fg = c.bg, bg = c.purple, bold = true })
  hl(0, "MiniStatuslineModeCommand", { fg = c.bg, bg = c.yellow, bold = true })
  hl(0, "MiniStatuslineModeReplace", { fg = c.bg, bg = c.red, bold = true })
  hl(0, "MiniStatuslineFilename", { fg = c.fg_dim, bg = c.bg_alt })

  -- ==========================================================================
  -- Terminal colors
  -- ==========================================================================
  vim.g.terminal_color_0 = c.bg_alt
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.aqua
  vim.g.terminal_color_7 = c.fg_dim
  vim.g.terminal_color_8 = c.blood
  vim.g.terminal_color_9 = c.red
  vim.g.terminal_color_10 = c.green
  vim.g.terminal_color_11 = c.yellow
  vim.g.terminal_color_12 = c.blue
  vim.g.terminal_color_13 = c.purple
  vim.g.terminal_color_14 = c.aqua
  vim.g.terminal_color_15 = c.fg
end

-- Apply
apply_gruvbox()

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = apply_gruvbox,
})
