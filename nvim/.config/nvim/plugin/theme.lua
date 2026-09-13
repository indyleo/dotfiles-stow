-- ~/.config/nvim/plugins/gruvbox.lua

local Gruvbox = {}

local default_config = {
  terminal_colors = true,
  undercurl = true,
  underline = true,
  bold = true,
  italic = {
    strings = true,
    emphasis = true,
    comments = true,
    operators = false,
    folds = true,
  },
  strikethrough = true,
  invert_selection = false,
  invert_signs = false,
  invert_tabline = false,
  inverse = true,
  contrast = "",
  palette_overrides = {},
  overrides = {},
  dim_inactive = false,
  transparent_mode = true,
}

Gruvbox.config = vim.deepcopy(default_config)

Gruvbox.palette = {
  dark0_hard = "#1d2021",
  dark0 = "#282828",
  dark0_soft = "#32302f",
  dark1 = "#3c3836",
  dark2 = "#504945",
  dark3 = "#665c54",
  dark4 = "#7c6f64",
  light0_hard = "#f9f5d7",
  light0 = "#fbf1c7",
  light0_soft = "#f2e5bc",
  light1 = "#ebdbb2",
  light2 = "#d5c4a1",
  light3 = "#bdae93",
  light4 = "#a89984",
  bright_red = "#fb4934",
  bright_green = "#b8bb26",
  bright_yellow = "#fabd2f",
  bright_blue = "#83a598",
  bright_purple = "#d3869b",
  bright_aqua = "#8ec07c",
  bright_orange = "#fe8019",
  neutral_red = "#cc241d",
  neutral_green = "#98971a",
  neutral_yellow = "#d79921",
  neutral_blue = "#458588",
  neutral_purple = "#b16286",
  neutral_aqua = "#689d6a",
  neutral_orange = "#d65d0e",
  faded_red = "#9d0006",
  faded_green = "#79740e",
  faded_yellow = "#b57614",
  faded_blue = "#076678",
  faded_purple = "#8f3f71",
  faded_aqua = "#427b58",
  faded_orange = "#af3a03",
  dark_red = "#722529",
  light_red = "#fc9487",
  dark_green = "#62693e",
  light_green = "#d5d39b",
  dark_aqua = "#49503b",
  light_aqua = "#e8e5b5",
  gray = "#928374",
}

local function get_colors()
  local p = Gruvbox.palette
  local config = Gruvbox.config

  for color, hex in pairs(config.palette_overrides) do
    p[color] = hex
  end

  -- fixed dark background; this file doesn't support a light variant
  return {
    bg0 = p.dark0,
    bg1 = p.dark1,
    bg2 = p.dark2,
    bg3 = p.dark3,
    bg4 = p.dark4,
    fg0 = p.light0,
    fg1 = p.light1,
    fg2 = p.light2,
    fg3 = p.light3,
    fg4 = p.light4,
    red = p.bright_red,
    green = p.bright_green,
    yellow = p.bright_yellow,
    blue = p.bright_blue,
    purple = p.bright_purple,
    aqua = p.bright_aqua,
    orange = p.bright_orange,
    neutral_red = p.neutral_red,
    neutral_green = p.neutral_green,
    neutral_yellow = p.neutral_yellow,
    neutral_blue = p.neutral_blue,
    neutral_purple = p.neutral_purple,
    neutral_aqua = p.neutral_aqua,
    dark_red = p.dark_red,
    dark_green = p.dark_green,
    dark_aqua = p.dark_aqua,
    gray = p.gray,
  }
end

local function get_groups()
  local colors = get_colors()
  local config = Gruvbox.config
  local t = config.transparent_mode

  if config.terminal_colors then
    local term_colors = {
      colors.bg0,
      colors.neutral_red,
      colors.neutral_green,
      colors.neutral_yellow,
      colors.neutral_blue,
      colors.neutral_purple,
      colors.neutral_aqua,
      colors.fg4,
      colors.gray,
      colors.red,
      colors.green,
      colors.yellow,
      colors.blue,
      colors.purple,
      colors.aqua,
      colors.fg1,
    }
    for index, value in ipairs(term_colors) do
      vim.g["terminal_color_" .. index - 1] = value
    end
  end

  local groups = {
    GruvboxFg0 = { fg = colors.fg0 },
    GruvboxFg1 = { fg = colors.fg1 },
    GruvboxFg2 = { fg = colors.fg2 },
    GruvboxFg3 = { fg = colors.fg3 },
    GruvboxFg4 = { fg = colors.fg4 },
    GruvboxGray = { fg = colors.gray },
    GruvboxBg0 = { fg = colors.bg0 },
    GruvboxBg1 = { fg = colors.bg1 },
    GruvboxBg2 = { fg = colors.bg2 },
    GruvboxBg3 = { fg = colors.bg3 },
    GruvboxBg4 = { fg = colors.bg4 },
    GruvboxRed = { fg = colors.red },
    GruvboxRedBold = { fg = colors.red, bold = config.bold },
    GruvboxGreen = { fg = colors.green },
    GruvboxGreenBold = { fg = colors.green, bold = config.bold },
    GruvboxYellow = { fg = colors.yellow },
    GruvboxYellowBold = { fg = colors.yellow, bold = config.bold },
    GruvboxBlue = { fg = colors.blue },
    GruvboxBlueBold = { fg = colors.blue, bold = config.bold },
    GruvboxPurple = { fg = colors.purple },
    GruvboxPurpleBold = { fg = colors.purple, bold = config.bold },
    GruvboxAqua = { fg = colors.aqua },
    GruvboxAquaBold = { fg = colors.aqua, bold = config.bold },
    GruvboxOrange = { fg = colors.orange },
    GruvboxOrangeBold = { fg = colors.orange, bold = config.bold },
    GruvboxRedSign = t and { fg = colors.red, reverse = config.invert_signs } or { fg = colors.red, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxGreenSign = t and { fg = colors.green, reverse = config.invert_signs } or { fg = colors.green, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxYellowSign = t and { fg = colors.yellow, reverse = config.invert_signs } or { fg = colors.yellow, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxBlueSign = t and { fg = colors.blue, reverse = config.invert_signs } or { fg = colors.blue, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxPurpleSign = t and { fg = colors.purple, reverse = config.invert_signs } or { fg = colors.purple, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxAquaSign = t and { fg = colors.aqua, reverse = config.invert_signs } or { fg = colors.aqua, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxOrangeSign = t and { fg = colors.orange, reverse = config.invert_signs } or { fg = colors.orange, bg = colors.bg1, reverse = config.invert_signs },
    GruvboxRedUnderline = { undercurl = config.undercurl, sp = colors.red },
    GruvboxGreenUnderline = { undercurl = config.undercurl, sp = colors.green },
    GruvboxYellowUnderline = { undercurl = config.undercurl, sp = colors.yellow },
    GruvboxBlueUnderline = { undercurl = config.undercurl, sp = colors.blue },
    GruvboxPurpleUnderline = { undercurl = config.undercurl, sp = colors.purple },
    GruvboxAquaUnderline = { undercurl = config.undercurl, sp = colors.aqua },
    GruvboxOrangeUnderline = { undercurl = config.undercurl, sp = colors.orange },
    Normal = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg0 },
    NormalFloat = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg1 },
    NormalNC = t and { fg = colors.fg0, bg = nil } or (config.dim_inactive and { fg = colors.fg0, bg = colors.bg1 } or { link = "Normal" }),
    MsgArea = t and { bg = nil } or {},
    CursorLine = { bg = colors.bg1 },
    CursorColumn = { link = "CursorLine" },
    TabLineFill = { fg = colors.bg4, bg = colors.bg1, reverse = config.invert_tabline },
    TabLineSel = { fg = colors.green, bg = colors.bg1, reverse = config.invert_tabline },
    TabLine = { link = "TabLineFill" },
    MatchParen = { bg = colors.bg3, bold = config.bold },
    ColorColumn = { bg = colors.bg1 },
    Conceal = { fg = colors.blue },
    CursorLineNr = { fg = colors.yellow, bg = colors.bg1 },
    NonText = { link = "GruvboxBg2" },
    SpecialKey = { link = "GruvboxFg4" },
    Visual = { bg = colors.bg3, reverse = config.invert_selection },
    VisualNOS = { link = "Visual" },
    Search = { fg = colors.yellow, bg = colors.bg0, reverse = config.inverse },
    IncSearch = { fg = colors.orange, bg = colors.bg0, reverse = config.inverse },
    CurSearch = { link = "IncSearch" },
    QuickFixLine = { link = "GruvboxPurple" },
    Underlined = { fg = colors.blue, underline = config.underline },
    StatusLine = { fg = colors.fg1, bg = colors.bg2 },
    StatusLineNC = { fg = colors.fg4, bg = colors.bg1 },
    WinBar = { fg = colors.fg4, bg = colors.bg0 },
    WinBarNC = { fg = colors.fg3, bg = colors.bg1 },
    WinSeparator = t and { fg = colors.bg3, bg = nil } or { fg = colors.bg3, bg = colors.bg0 },
    WildMenu = { fg = colors.blue, bg = colors.bg2, bold = config.bold },
    Directory = { link = "GruvboxGreenBold" },
    Title = { link = "GruvboxGreenBold" },
    ErrorMsg = { fg = colors.bg0, bg = colors.red, bold = config.bold },
    MoreMsg = { link = "GruvboxYellowBold" },
    ModeMsg = { link = "GruvboxYellowBold" },
    Question = { link = "GruvboxOrangeBold" },
    WarningMsg = { link = "GruvboxRedBold" },
    LineNr = { fg = colors.bg4 },
    SignColumn = t and { bg = nil } or { bg = colors.bg1 },
    Folded = { fg = colors.gray, bg = colors.bg1, italic = config.italic.folds },
    FoldColumn = t and { fg = colors.gray, bg = nil } or { fg = colors.gray, bg = colors.bg1 },
    Cursor = { reverse = config.inverse },
    vCursor = { link = "Cursor" },
    iCursor = { link = "Cursor" },
    lCursor = { link = "Cursor" },
    Special = { link = "GruvboxOrange" },
    Comment = { fg = colors.gray, italic = config.italic.comments },
    Todo = { fg = colors.bg0, bg = colors.yellow, bold = config.bold, italic = config.italic.comments },
    Done = { fg = colors.orange, bold = config.bold, italic = config.italic.comments },
    Error = { fg = colors.red, bold = config.bold, reverse = config.inverse },
    Statement = { link = "GruvboxRed" },
    Conditional = { link = "GruvboxRed" },
    Repeat = { link = "GruvboxRed" },
    Label = { link = "GruvboxRed" },
    Exception = { link = "GruvboxRed" },
    Operator = { fg = colors.orange, italic = config.italic.operators },
    Keyword = { fg = colors.red, bold = config.bold },
    Identifier = { link = "GruvboxBlue" },
    Function = { link = "GruvboxGreenBold" },
    PreProc = { link = "GruvboxAqua" },
    Include = { link = "GruvboxAqua" },
    Define = { link = "GruvboxAqua" },
    Macro = { link = "GruvboxAqua" },
    PreCondit = { link = "GruvboxAqua" },
    Constant = { link = "GruvboxPurple" },
    Character = { link = "GruvboxPurple" },
    String = { fg = colors.green, italic = config.italic.strings },
    Boolean = { link = "GruvboxPurple" },
    Number = { link = "GruvboxPurple" },
    Float = { link = "GruvboxPurple" },
    Type = { link = "GruvboxYellow" },
    StorageClass = { link = "GruvboxOrange" },
    Structure = { link = "GruvboxAqua" },
    Typedef = { link = "GruvboxYellow" },
    Pmenu = { fg = colors.fg1, bg = colors.bg2 },
    PmenuSel = { fg = colors.bg2, bg = colors.blue, bold = config.bold },
    PmenuSbar = { bg = colors.bg2 },
    PmenuThumb = { bg = colors.bg4 },
    DiffDelete = { bg = colors.dark_red },
    DiffAdd = { bg = colors.dark_green },
    DiffChange = { bg = colors.dark_aqua },
    DiffText = { bg = colors.yellow, fg = colors.bg0 },
    SpellCap = { link = "GruvboxBlueUnderline" },
    SpellBad = { link = "GruvboxRedUnderline" },
    SpellLocal = { link = "GruvboxAquaUnderline" },
    SpellRare = { link = "GruvboxPurpleUnderline" },
    Whitespace = { fg = colors.bg2 },
    Delimiter = { link = "GruvboxOrange" },
    EndOfBuffer = t and { fg = colors.bg0, bg = nil } or { link = "NonText" },
    DiagnosticError = { link = "GruvboxRed" },
    DiagnosticWarn = { link = "GruvboxYellow" },
    DiagnosticInfo = { link = "GruvboxBlue" },
    DiagnosticDeprecated = { strikethrough = config.strikethrough },
    DiagnosticHint = { link = "GruvboxAqua" },
    DiagnosticOk = { link = "GruvboxGreen" },
    DiagnosticSignError = { link = "GruvboxRedSign" },
    DiagnosticSignWarn = { link = "GruvboxYellowSign" },
    DiagnosticSignInfo = { link = "GruvboxBlueSign" },
    DiagnosticSignHint = { link = "GruvboxAquaSign" },
    DiagnosticSignOk = { link = "GruvboxGreenSign" },
    DiagnosticUnderlineError = { link = "GruvboxRedUnderline" },
    DiagnosticUnderlineWarn = { link = "GruvboxYellowUnderline" },
    DiagnosticUnderlineInfo = { link = "GruvboxBlueUnderline" },
    DiagnosticUnderlineHint = { link = "GruvboxAquaUnderline" },
    DiagnosticUnderlineOk = { link = "GruvboxGreenUnderline" },
    DiagnosticFloatingError = { link = "GruvboxRed" },
    DiagnosticFloatingWarn = { link = "GruvboxOrange" },
    DiagnosticFloatingInfo = { link = "GruvboxBlue" },
    DiagnosticFloatingHint = { link = "GruvboxAqua" },
    DiagnosticFloatingOk = { link = "GruvboxGreen" },
    DiagnosticVirtualTextError = { fg = colors.red, bg = nil },
    DiagnosticVirtualTextWarn = { fg = colors.yellow, bg = nil },
    DiagnosticVirtualTextInfo = { fg = colors.blue, bg = nil },
    DiagnosticVirtualTextHint = { fg = colors.aqua, bg = nil },
    DiagnosticVirtualTextOk = { fg = colors.green, bg = nil },
    LspReferenceRead = { bg = colors.bg2 },
    LspReferenceTarget = { link = "Visual" },
    LspReferenceText = { bg = colors.bg2 },
    LspReferenceWrite = { bg = colors.bg2, underline = config.underline },
    LspCodeLens = { link = "GruvboxGray" },
    LspSignatureActiveParameter = { link = "Search" },
    LspInlayHint = { link = "Comment" },
    gitcommitSelectedFile = { link = "GruvboxGreen" },
    gitcommitDiscardedFile = { link = "GruvboxRed" },
    GitSignsAdd = { link = "GruvboxGreen" },
    GitSignsChange = { link = "GruvboxOrange" },
    GitSignsDelete = { link = "GruvboxRed" },
    GitSignsChangedelete = { link = "GruvboxOrange" },
    GitSignsTopdelete = { link = "GruvboxRed" },
    GitSignsCurrentLineBlame = { fg = colors.gray, italic = true },
    GitSignsAddPreview = { fg = colors.green, bg = colors.bg1 },
    GitSignsDeletePreview = { fg = colors.red, bg = colors.bg1 },
    NvimTreeNormal = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg0 },
    NvimTreeWinSeparator = t and { fg = colors.bg3, bg = nil } or { fg = colors.bg3, bg = colors.bg0 },
    NvimTreeSymlink = { fg = colors.neutral_aqua },
    NvimTreeRootFolder = { fg = colors.neutral_purple, bold = true },
    NvimTreeFolderIcon = { fg = colors.neutral_blue, bold = true },
    NvimTreeFolderName = { fg = colors.blue },
    NvimTreeOpenedFolderName = { fg = colors.blue, bold = true },
    NvimTreeFileIcon = { fg = colors.light2 },
    NvimTreeExecFile = { fg = colors.neutral_green, bold = true },
    NvimTreeOpenedFile = { fg = colors.bright_red, bold = true },
    NvimTreeSpecialFile = { fg = colors.neutral_yellow, bold = true, underline = true },
    NvimTreeImageFile = { fg = colors.neutral_purple },
    NvimTreeIndentMarker = { fg = colors.dark3 },
    NvimTreeGitDirty = { fg = colors.neutral_yellow },
    NvimTreeGitStaged = { fg = colors.neutral_yellow },
    NvimTreeGitMerge = { fg = colors.neutral_purple },
    NvimTreeGitRenamed = { fg = colors.neutral_purple },
    NvimTreeGitNew = { fg = colors.neutral_yellow },
    NvimTreeGitDeleted = { fg = colors.neutral_red },
    NvimTreeWindowPicker = { bg = colors.aqua },
    NeoTreeNormal = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg0 },
    NeoTreeWinSeparator = t and { fg = colors.bg3, bg = nil } or { fg = colors.bg3, bg = colors.bg0 },
    NeoTreeDirectoryIcon = { fg = colors.neutral_aqua },
    NeoTreeDirectoryName = { link = "GruvboxGreenBold" },
    NeoTreeRootName = { fg = colors.orange, bold = true },
    NeoTreeIndentMarker = { fg = colors.bg2 },
    NeoTreeGitAdded = { link = "GruvboxGreen" },
    NeoTreeGitModified = { link = "GruvboxYellow" },
    NeoTreeGitDeleted = { link = "GruvboxRed" },
    NeoTreeFloatBorder = { link = "GruvboxGray" },
    NeoTreeTitleBar = { fg = colors.fg1, bg = colors.bg2 },
    -- which-key.nvim (not in the original table)
    WhichKey = { fg = colors.blue, bold = config.bold },
    WhichKeyGroup = { link = "GruvboxOrange" },
    WhichKeyDesc = { fg = colors.fg1 },
    WhichKeySeparator = { fg = colors.gray },
    WhichKeyNormal = t and { bg = nil } or { bg = colors.bg1 },
    WhichKeyBorder = { fg = colors.blue, bg = nil },
    WhichKeyValue = { fg = colors.fg3 },
    WhichKeyTitle = { link = "NormalFloat" },
    -- fzf-lua (not in the original table)
    FzfLuaNormal = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg0 },
    FzfLuaBorder = { fg = colors.blue, bg = nil },
    FzfLuaTitle = { fg = colors.bg0, bg = colors.blue, bold = config.bold },
    FzfLuaPreviewNormal = t and { fg = colors.fg1, bg = nil } or { fg = colors.fg1, bg = colors.bg0 },
    FzfLuaPreviewBorder = { fg = colors.bg2, bg = nil },
    FzfLuaPreviewTitle = { fg = colors.bg0, bg = colors.yellow, bold = config.bold },
    FzfLuaCursor = { fg = colors.bg0, bg = colors.fg1 },
    FzfLuaCursorLine = { bg = colors.bg2 },
    FzfLuaCursorLineNr = { fg = colors.yellow, bold = config.bold },
    FzfLuaScrollBorderEmpty = { fg = colors.bg2 },
    FzfLuaScrollBorderFull = { fg = colors.blue },
    FzfLuaHeaderBind = { fg = colors.orange },
    FzfLuaHeaderText = { fg = colors.fg3 },
    FzfLuaPathColNr = { fg = colors.purple },
    FzfLuaPathLineNr = { fg = colors.gray },
    FzfLuaBufName = { fg = colors.blue },
    FzfLuaBufNr = { fg = colors.purple },
    FzfLuaBufFlagCur = { fg = colors.yellow },
    FzfLuaBufFlagAlt = { fg = colors.orange },
    FzfLuaTabTitle = { fg = colors.yellow, bold = config.bold },
    FzfLuaTabMarker = { fg = colors.red },
    FzfLuaLiveSym = { fg = colors.yellow, bold = config.bold },
    FzfLuaFzfMatch = { fg = colors.yellow, bold = config.bold },
    FzfLuaFzfPointer = { fg = colors.red },
    FzfLuaFzfMarker = { fg = colors.green },
    -- bufferline.nvim (not in the original table)
    BufferLineFill = { bg = nil },
    BufferLineBackground = { fg = colors.fg3, bg = nil },
    BufferLineBufferSelected = { fg = colors.yellow, bg = colors.bg2, bold = config.bold },
    BufferLineIndicatorSelected = { fg = colors.yellow },
    BufferLineSeparator = { fg = colors.bg0, bg = nil },
    BufferLineModified = { fg = colors.orange },
    BufferLineModifiedSelected = { fg = colors.orange },
    BufferLineCloseButton = { fg = colors.fg3 },
    BufferLineCloseButtonSelected = { fg = colors.red },
    -- indent-blankline.nvim / ibl (not in the original table)
    IblIndent = { fg = colors.bg2 },
    IblScope = { fg = colors.orange },
    IblWhitespace = { fg = colors.bg2 },
    -- trouble.nvim (not in the original table)
    TroubleNormal = { bg = nil },
    TroubleText = { fg = colors.fg1 },
    TroubleCount = { fg = colors.yellow },
    TroubleFile = { fg = colors.blue },
    TroubleIndent = { fg = colors.bg2 },
    TroubleFoldIcon = { fg = colors.orange },
    TroubleLocation = { fg = colors.gray },
    -- noice.nvim
    NoiceCursor = { link = "TermCursor" },
    NoiceCmdlinePopupBorder = { fg = colors.blue, bg = nil },
    NoiceCmdlinePopupTitle = { fg = colors.yellow, bold = config.bold },
    NoiceCmdlineIcon = { link = "NoiceCmdlinePopupBorder" },
    NoiceConfirmBorder = { link = "NoiceCmdlinePopupBorder" },
    NoiceCmdlinePopupBorderSearch = { fg = colors.yellow, bg = nil },
    NoiceCmdlineIconSearch = { link = "NoiceCmdlinePopupBorderSearch" },
    -- nvim-cmp / blink.cmp
    CmpBorder = { fg = colors.bg2, bg = nil },
    CmpDocBorder = { fg = colors.bg2, bg = nil },
    BlinkCmpMenuBorder = { fg = colors.bg2, bg = nil },
    BlinkCmpDocBorder = { fg = colors.bg2, bg = nil },
    CmpItemAbbr = { link = "GruvboxFg0" },
    CmpItemAbbrDeprecated = { link = "GruvboxFg1" },
    CmpItemAbbrMatch = { link = "GruvboxBlueBold" },
    CmpItemAbbrMatchFuzzy = { link = "GruvboxBlueUnderline" },
    CmpItemMenu = { link = "GruvboxGray" },
    CmpItemKindFunction = { link = "GruvboxGreen" },
    CmpItemKindMethod = { link = "GruvboxGreen" },
    CmpItemKindVariable = { link = "GruvboxBlue" },
    CmpItemKindField = { link = "GruvboxBlue" },
    CmpItemKindProperty = { link = "GruvboxBlue" },
    CmpItemKindKeyword = { link = "GruvboxRed" },
    CmpItemKindClass = { link = "GruvboxYellow" },
    CmpItemKindInterface = { link = "GruvboxYellow" },
    CmpItemKindModule = { link = "GruvboxAqua" },
    CmpItemKindSnippet = { link = "GruvboxGreen" },
    CmpItemKindConstant = { link = "GruvboxOrange" },
    CmpItemKindText = { link = "GruvboxOrange" },
    CmpItemKindFile = { link = "GruvboxBlue" },
    -- markdown / prose
    markdownH1 = { link = "GruvboxGreenBold" },
    markdownH2 = { link = "GruvboxGreenBold" },
    markdownH3 = { link = "GruvboxYellowBold" },
    markdownCode = { link = "GruvboxAqua" },
    markdownCodeBlock = { link = "GruvboxAqua" },
    markdownLinkText = { fg = colors.gray, underline = config.underline },
    -- treesitter
    ["@comment"] = { link = "Comment" },
    ["@string"] = { link = "String" },
    ["@string.escape"] = { fg = colors.orange },
    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { fg = colors.green, italic = true },
    ["@function.call"] = { link = "Function" },
    ["@method"] = { link = "Function" },
    ["@method.call"] = { link = "Function" },
    ["@constructor"] = { link = "GruvboxYellow" },
    ["@variable"] = { link = "GruvboxFg1" },
    ["@variable.builtin"] = { link = "GruvboxRed" },
    ["@variable.parameter"] = { fg = colors.fg1, italic = true },
    ["@variable.member"] = { link = "GruvboxBlue" },
    ["@property"] = { link = "GruvboxBlue" },
    ["@field"] = { link = "GruvboxBlue" },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { fg = colors.purple, bold = config.bold },
    ["@keyword"] = { link = "Keyword" },
    ["@keyword.function"] = { link = "Keyword" },
    ["@keyword.return"] = { link = "Keyword" },
    ["@tag"] = { link = "GruvboxRed" },
    ["@tag.attribute"] = { link = "GruvboxYellow" },
    ["@tag.delimiter"] = { link = "GruvboxBlue" },
    ["@punctuation.bracket"] = { link = "Delimiter" },
    ["@punctuation.delimiter"] = { link = "Delimiter" },
    ["@punctuation.special"] = { link = "GruvboxOrange" },
    ["@text.title"] = { link = "Title" },
    ["@text.literal"] = { link = "String" },
    ["@text.uri"] = { link = "Underlined" },
  }

  for group, hl in pairs(config.overrides) do
    if groups[group] then
      groups[group].link = nil
    end
    groups[group] = vim.tbl_extend("force", groups[group] or {}, hl)
  end

  return groups
end

---@param config table?
Gruvbox.setup = function(config)
  Gruvbox.config = vim.deepcopy(default_config)
  Gruvbox.config = vim.tbl_deep_extend("force", Gruvbox.config, config or {})
end

Gruvbox.load = function()
  if vim.g.colors_name then
    vim.cmd.hi "clear"
  end
  vim.g.colors_name = "gruvbox"
  vim.o.termguicolors = true
  vim.o.background = "dark"

  local groups = get_groups()

  for group, settings in pairs(groups) do
    vim.api.nvim_set_hl(0, group, settings)
  end
end

-- ============================================================================
-- Apply immediately, like a normal init-time colorscheme script — no plugin
-- manager entry, no `require("gruvbox")` from an installed package.
-- ============================================================================

local function apply()
  Gruvbox.setup { transparent_mode = true }
  Gruvbox.load()

  if vim.g.neovide then
    vim.g.neovide_background_opacity = 0.85
    vim.g.neovide_normal_opacity = 0.85
    vim.g.neovide_cursor_vfx_mode = "railgun"
    vim.g.neovide_cursor_vfx_color = Gruvbox.palette.bright_red
    vim.g.neovide_cursor_animation_length = 0.08
    vim.g.neovide_cursor_trail_size = 0.5
    vim.g.neovide_floating_shadow = false
    vim.g.neovide_floating_blur_amount_x = 2.0
    vim.g.neovide_floating_blur_amount_y = 2.0
    vim.api.nvim_set_hl(0, "Normal", { fg = Gruvbox.palette.light1, bg = Gruvbox.palette.dark0 })
  end
end

apply()

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = apply,
})

return Gruvbox
