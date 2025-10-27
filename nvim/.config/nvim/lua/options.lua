local opt = vim.opt
local cmd = vim.cmd

-- ========================
-- Vim Commands
-- ========================
cmd [[ let g:netrw_liststyle = 1 ]]

-- ========================
-- Options grouped in tables
-- ========================

-- Boolean options
local bool_opts = {
  backup = false,
  writebackup = false,
  swapfile = false,
  undofile = true,
  cursorline = true,
  number = true,
  relativenumber = true,
  wrap = false,
  showmode = false,
  title = true,
  foldenable = true,
  termguicolors = true,
  linebreak = true,
}

for k, v in pairs(bool_opts) do
  opt[k] = v
end

-- Number options
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

-- String options
local str_opts = {
  clipboard = "unnamedplus",
  fileencoding = "utf-8",
  signcolumn = "yes",
  shell = "zsh",
  mouse = "",
  titlestring = "Neovim - %t (%{expand('%:p:h')})",
  winborder = "rounded",
  foldmethod = "expr",
  foldexpr = "nvim_treesitter#foldexpr()",
  completeopt = "menuone,noselect",
}

for k, v in pairs(str_opts) do
  opt[k] = v
end

-- Append / remove options
opt.shortmess:append "c"
opt.whichwrap:append "<,>,[,],h,l"
opt.iskeyword:append "-"
opt.formatoptions:remove { "c", "r", "o" }
opt.fillchars = { eob = " ", foldopen = "▾", foldclose = "▸" }
