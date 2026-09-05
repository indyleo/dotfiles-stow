local opt = vim.opt
local cmd = vim.cmd

-- ========================
-- Vim Commands
-- ========================
cmd [[
let g:netrw_liststyle = 1
let g:netrw_banner = 0
let g:netrw_preview = 1
]]

-- ========================
-- Disable providers
-- ========================
local providers = { "node", "perl", "ruby" }
for _, provider in ipairs(providers) do
  vim.g["loaded_" .. provider .. "_provider"] = 0
end

-- ========================
-- Boolean options
-- ========================
local bool_opts = {
  backup = false,
  writebackup = false,
  swapfile = false,
  undofile = true,
  cursorline = true,
  number = true,
  relativenumber = true,
  wrap = false,
  smartindent = true,
  showmode = false,
  title = true,
  foldenable = true,
  termguicolors = true,
  linebreak = true,
  splitbelow = true,
  splitright = true,
  ignorecase = true,
  smartcase = true,
}
for k, v in pairs(bool_opts) do
  opt[k] = v
end

-- ========================
-- Number options
-- ========================
local num_opts = {
  timeoutlen = 300,
  updatetime = 300,
  scrolloff = 8,
  sidescrolloff = 8,
  shiftwidth = 2,
  tabstop = 2,
  numberwidth = 4,
  cmdheight = 1,
  pumheight = 10,
  foldlevel = 99,
  foldlevelstart = 99,
  laststatus = 3,
}
for k, v in pairs(num_opts) do
  opt[k] = v
end

-- ========================
-- String options
-- ========================
local str_opts = {
  clipboard = "unnamedplus",
  fileencoding = "utf-8",
  signcolumn = "yes",
  shell = "zsh",
  mouse = "",
  inccommand = "split",
  titlestring = "Neovim - %t (%{expand('%:p:h')})",
  winborder = "rounded",
  foldmethod = "expr",
  -- NOTE: `nvim_treesitter#foldexpr()` was the old nvim-treesitter (legacy
  -- branch) Vimscript folding function. The `main`/default branch installed
  -- via lua/config/pack.lua removed it, so this would throw "Unknown
  -- function" errors on every fold recompute. Neovim core has shipped its
  -- own treesitter-based foldexpr since 0.10 -- use that instead.
  foldexpr = "v:lua.vim.treesitter.foldexpr()",
  foldcolumn = "1",
  completeopt = "menuone,noselect",
  statusline = "%!v:lua.status_line()",
}
for k, v in pairs(str_opts) do
  opt[k] = v
end

-- ========================
-- Append / remove options
-- ========================
opt.shortmess:append "c"
opt.whichwrap:append "<,>,[,],h,l"
opt.iskeyword:append "-"
opt.formatoptions:remove { "c", "r", "o" }
opt.fillchars = { eob = " ", foldopen = "▾", foldclose = "▸" }