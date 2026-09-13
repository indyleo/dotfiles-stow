-- keymaps.lua
local keymap = vim.keymap.set

local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

local function map(modes, lhs, rhs, desc)
  keymap(modes, lhs, rhs, opts(desc))
end

-- Leader key
map("", "<Space>", "<Nop>", "Disable space")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--- Non-Plugin ----

-- Disable arrow keys in normal and visual modes
for _, key in ipairs { "<Up>", "<Down>", "<Left>", "<Right>" } do
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

-- Master/stack tiling (plugin/tile.lua)
map("n", "<M-CR>", ":TileSpawn<CR>", "Vertical split")
map("n", "<M-q>", ":close!<CR>", "Close split")
map("n", "<leader>wm", ":TileSwapMaster<CR>", "Tile: swap with master")
map("n", "<leader>wf", ":TileFocus<CR>", "Tile: focus master/stack")
map("n", "<leader>we", ":TileEqualize<CR>", "Tile: re-equalize stack")

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
map("n", "<leader>zq", ":PeekFold<CR>", "Peek folded lines under cursor")
map("n", "]z", ":NextFold<CR>", "Goes to next fold")
map("n", "[z", ":PrevFold<CR>", "Goes to previous fold")
map("n", "<leader>zR", ":FoldsForceRefresh<CR>", "Refresh all folds forcefully")
map("n", "<leader>zr", ":FoldsRefresh<CR>", "Refresh all folds")

-- Lf file manager
map("n", "<leader>ee", ":Lf<CR>", "Open file manager")

-- Undotree
map("n", "<leader>u", function()
  vim.cmd.packadd "nvim.undotree"
  vim.cmd "Undotree"
end, "Toggle undotree")

-- Marks
map("n", "<leader>mm", ":MarksAdd<CR>", "Add file to mark")
map("n", "<leader>mr", ":MarksDelete<CR>", "Remove file from mark")
map("n", "<leader>mt", ":MarksToggle<CR>", "Toggle Ui marks")

-- Jump
map("n", "<leader>jj", ":Jump<CR>", "Jump to search mark")
map("n", "<leader>jw", ":JumpWord<CR>", "Jump to search mark (word prefix)")

-- Insert Mode
map("i", "jk", "<Esc>", "Exit insert mode")

-- Visual Mode
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")
map("v", "J", ":m '>+1<CR>gv=gv", "Move selection down")
map("v", "K", ":m '<-2<CR>gv=gv", "Move selection up")
map("v", "p", "P", "Paste over selection")
map("v", "P", '"_dP', "Paste over selection without overwriting register")

-- Visual Block Mode
map("x", "p", "P", "Paste over selection")
map("x", "P", '"_dP', "Paste over selection without overwriting register")

-- Terminal Mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal to normal mode")

-- Terminal toggles
map({ "n", "t" }, "<leader>tr", ":ToggleTerminal<CR>", "Toggle terminal")
map({ "n", "t" }, "<leader>tg", ":ToggleGit<CR>", "Toggle lazygit")
map({ "n", "t" }, "<leader>tc", ":ToggleClaude<CR>", "Toggle claude")

--- Plugins ----

-- Noice
map("n", "<leader>nh", ":NoiceDismiss<CR>", "Dismiss noice notifications")

-- Fzf Lua
local fzf = {
  ff = "files",
  fr = "oldfiles",
  fs = "grep",
  fc = "grep_cword",
  fg = "git_files",
  fh = "helptags",
  fk = "keymaps",
}
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
      ["[d"] = function()
        vim.diagnostic.jump { count = -1 }
      end,
      ["]d"] = function()
        vim.diagnostic.jump { count = 1 }
      end,
      ["gK"] = vim.lsp.buf.hover,
      ["<leader>rs"] = ":LspRestart<CR>",
    }

    for k, v in pairs(lsp_maps) do
      keymap("n", k, v, lspopts(k))
    end

    vim.notify("LSP attached to: " .. vim.fn.expand "%:t", vim.log.levels.INFO)
  end,
})

--- Neovide / GUI ----
if vim.g.neovide then
  -- Font scaling
  local function resize_font(delta)
    vim.g.neovide_scale_factor = math.max(0.5, (vim.g.neovide_scale_factor or 1.0) + delta)
  end
  map({ "n", "i" }, "<C-=>", function()
    resize_font(0.1)
  end, "Neovide: increase font scale")
  map({ "n", "i" }, "<C-->", function()
    resize_font(-0.1)
  end, "Neovide: decrease font scale")
  map({ "n", "i" }, "<C-0>", function()
    vim.g.neovide_scale_factor = 1.0
  end, "Neovide: reset font scale")

  -- Fullscreen toggle
  map("n", "<F11>", function()
    vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
  end, "Neovide: toggle fullscreen")

  -- Opacity toggle (handy when you need to peek at what's behind the window)
  map("n", "<leader>gt", function()
    vim.g.neovide_opacity = (vim.g.neovide_opacity < 1.0) and 1.0 or 0.85
  end, "Neovide: toggle transparency")

  -- System clipboard copy/paste using the OS modifier (Cmd on macOS, Ctrl elsewhere via neovide_input_use_logo)
  map("v", "<D-c>", '"+y', "Neovide: copy to system clipboard")
  map({ "n", "v" }, "<D-v>", '"+p', "Neovide: paste from system clipboard")
  map("i", "<D-v>", "<C-r>+", "Neovide: paste from system clipboard (insert)")
  map("c", "<D-v>", "<C-r>+", "Neovide: paste from system clipboard (cmdline)")
  map("t", "<D-v>", '<C-\\><C-n>"+pi', "Neovide: paste from system clipboard (terminal)")
end
