-- Shorten function name
local keymap = vim.keymap.set

-- Keymap options helper
local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

-- Helper for multiple modes
local function map(modes, lhs, rhs, desc)
  keymap(modes, lhs, rhs, opts(desc))
end

-- Leader key
map("", "<Space>", "<Nop>", "Disable space")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

---- Non-Plugin ----

-- Normal Mode --

-- Disable arrow keys in normal and visual modes
for _, key in ipairs { "<Up>", "<Down>", "<Left>", "<Right> " } do
  map({ "n", "v", "x" }, key, "<Nop>", "Disable " .. key)
end

-- Window navigation
for _, k in pairs { h = "h", j = "j", k = "k", l = "l" } do
  map("n", "<C-" .. k .. ">", "<C-w>" .. k, "Move to window " .. k)
end

-- Resize splits
local resize_map = { h = "+2", l = "-2", j = "+2", k = "-2" }
for k, v in pairs(resize_map) do
  local cmd = (k == "h" or k == "l") and ":vertical resize " .. v .. "<CR>" or ":resize " .. v .. "<CR>"
  map("n", "<M-" .. k .. ">", cmd, "Resize " .. k)
end
map("n", "<M-=>", "<C-w>=", "Equalize window sizes")

-- Make splits
map("n", "<M-v>", ":vsplit<CR>", "Vertical split")
map("n", "<M-s>", ":split<CR>", "Horizontal split")
map("n", "<M-q>", ":close!<CR>", "Close split")

-- Buffer navigation
map("n", "<S-l>", ":bnext<CR>", "Next buffer")
map("n", "<S-h>", ":bprevious<CR>", "Previous buffer")
map("n", "<S-q>", ":Bdelete!<CR>", "Delete buffer")

-- Quickfix navigation
map("n", "<leader>qn", ":cnext<CR>zz", "Next quickfix")
map("n", "<leader>qp", ":cprev<CR>zz", "Previous quickfix")
map("n", "<leader>ql", ":lnext<CR>zz", "Next location")
map("n", "<leader>qk", ":lprev<CR>zz", "Previous location")
map("n", "<leader>qf", function()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      vim.cmd "cclose"
      return
    end
  end
  vim.cmd "copen"
end, "Toggle Quickfix")

-- Clear highlights
map("n", "<leader>hl", ":nohlsearch<CR>", "Clear highlights")

-- Increment/Decrement numbers
map("n", "a", "<C-a>", "Increment number")
map("n", "q", "<C-x>", "Decrement number")

-- Commenting
map("n", "<leader>/", ":ToggleComment<CR>", "Toggle comment")
map("v", "<leader>/", ":ToggleCommentVisual<CR>", "Toggle comment Visual")

-- Folding
map("n", "<leader>za", ":ToggleAllFolds<CR>", "Toggle all folds")
map("n", "<leader>zs", ":ToggleFold<CR>", "Toggle fold under cursor")
map("n", "<leader>zq", ":PeekFold<CR>", "Peek folded lines or LSP hover")
map("n", "]z", ":NextFold<CR>", "Goes to next fold")
map("n", "[z", ":PrevFold<CR>", "Goes to previous fold")
map("n", "<leader>zR", ":FoldsForceRefresh<CR>", "Refresh all folds forcefully")
map("n", "<leader>zr", ":FoldsRefresh<CR>", "Refresh all folds")

-- Lf file manager
map("n", "<leader>ee", ":Lf<CR>", "Open file manager")

-- Insert Mode --
map("i", "jk", "<Esc>", "Exit insert mode")

-- Visual Mode --
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")
map("v", "J", ":m '>+1<CR>gv=gv", "Move selection down")
map("v", "K", ":m '<-2<CR>gv=gv", "Move selection up")
map("v", "p", "P", "Paste over selection")
map("v", "P", '"_dP', "Paste over selection without overwriting register")

-- Visual Block Mode --
map("x", "p", "P", "Paste over selection")
map("x", "P", '"_dP', "Paste over selection without overwriting register")

-- Terminal Mode --
map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal to normal mode")

-- Terminal toggles
map({ "n", "t" }, "<leader>tr", ":ToggleTerm<CR>", "Toggle terminal")
map({ "n", "t" }, "<leader>tg", ":ToggleGit<CR>", "Toggle fzf_git.py")

---- Plugins ----

-- Noice
map("n", "<leader>nh", ":NoiceDismiss<CR>", "Dismiss noice notifications")

-- Harpoon
map("n", "<leader>a", function()
  require("harpoon"):list():add()
end, "Mark a file")
map("n", "<leader>ha", function()
  require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
end, "Harpoon menu")
for i = 1, 5 do
  map("n", "<leader>" .. i, function()
    require("harpoon"):list():select(i)
  end, "Open file " .. i)
end

-- Fzf Lua
local fzf = { ff = "files", fr = "oldfiles", fs = "grep", fc = "grep_cword", fg = "git_files", fh = "helptags", fk = "keymaps" }
for k, v in pairs(fzf) do
  map("n", "<leader>" .. k, ":FzfLua " .. v .. "<CR>", "FzfLua " .. v)
end

-- Formatter/Linter
map("n", "<leader>ml", function()
  require("lint").try_lint()
end, "Lint current file")
map({ "n", "v" }, "<leader>mf", function()
  require("conform").format { lsp_fallback = true, async = false, timeout_ms = 1000 }
end, "Format file or selection")

-- LSP
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local lspopts = function(desc)
      return { buffer = bufnr, noremap = true, silent = true, desc = desc }
    end

    local lsp_maps = {
      ["gR"] = ":FzfLua lsp_references<CR>",
      ["gD"] = vim.lsp.buf.declaration,
      ["gd"] = ":FzfLua lsp_definitions<CR>",
      ["gi"] = ":FzfLua lsp_implementations<CR>",
      ["gt"] = ":FzfLua lsp_typedefs<CR>",
      ["<leader>ca"] = vim.lsp.buf.code_action,
      ["<leader>rn"] = vim.lsp.buf.rename,
      ["<leader>D"] = ":FzfLua diagnostics_document<CR>",
      ["<leader>d"] = vim.diagnostic.open_float,
      ["[d"] = vim.diagnostic.goto_prev,
      ["]d"] = vim.diagnostic.goto_next,
      ["gK"] = vim.lsp.buf.hover,
      ["<leader>rs"] = ":LspRestart<CR>",
    }

    for k, v in pairs(lsp_maps) do
      keymap("n", k, v, lspopts(k))
    end

    vim.notify("LSP attached to: " .. vim.fn.expand "%:t", vim.log.levels.INFO)
  end,
})

-- Undotree
map("n", "<leader>u", function()
  require("undotree").toggle()
end, "Toggle undotree")
