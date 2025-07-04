-- Shorten function name
local keymap = vim.keymap.set
-- Keymap option
local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end
local opt = { noremap = true, silent = true }

-- Remap space as leader key
keymap("", "<Space>", "<Nop>", opt)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes:
--   normal_mode       = "n"  -- Normal mode
--   insert_mode       = "i"  -- Insert mode
--   visual_mode       = "v"  -- Visual mode
--   visual_block_mode = "x"  -- Visual block mode
--   select_mode       = "s"  -- Select mode
--   term_mode         = "t"  -- Terminal mode
--   command_mode      = "c"  -- Command-line mode
--   operator_pending  = "o"  -- Operator-pending mode
--   replace_mode      = "R"  -- Replace mode
--   virtual_replace   = "gR" -- Virtual Replace mode
--   ex_mode           = "!"  -- Ex mode
--   hit-enter         = "r"  -- Hit-enter prompt
--   confirm_mode      = "cv" -- Confirm mode
--   more_mode         = "rm" -- More prompt
--   shell_mode        = "!"  -- Shell or external command execution
--   lang_arg_mode     = "l"  -- Language-specific argument completion
--   lang_map_mode     = "L"  -- Language-specific mappings

---- Non-Plugin ----

-- Normal --

-- Better window managment
keymap("n", "<C-h>", "<C-w>h", opt)
keymap("n", "<C-j>", "<C-w>j", opt)
keymap("n", "<C-k>", "<C-w>k", opt)
keymap("n", "<C-l>", "<C-w>l", opt)

-- Resize splits
keymap("n", "<M-h>", ":vertical resize +2<CR>", opt)
keymap("n", "<M-l>", ":vertical resize -2<CR>", opt)
keymap("n", "<M-j>", ":resize +2<CR>", opt)
keymap("n", "<M-k>", ":resize -2<CR>", opt)
keymap("n", "<M-=>", "<C-w>=", opt)

-- Making splits
keymap("n", "<M-v>", ":vsplit<CR>", opts "Makes a Vertical Spilt")
keymap("n", "<M-s>", ":split<CR>", opts "Makes a Horizontal Spilt")
keymap("n", "<M-q>", ":close!<CR>", opts "Kill a Spilt")

-- Buffer managment
keymap("n", "<S-l>", ":bnext<CR>", opt)
keymap("n", "<S-h>", ":bprevious<CR>", opt)
keymap("n", "<S-q>", ":Bdelete!<CR>", opt)

-- Quickfix list navigation
keymap("n", "<leader>qn", ":cnext<CR>zz", opts "Next quickfix")
keymap("n", "<leader>qp", ":cprev<CR>zz", opts "Previous quickfix")
keymap("n", "<leader>ql", ":lnext<CR>zz", opts "Next location")
keymap("n", "<leader>qk", ":lprev<CR>zz", opts "Previous location")
keymap("n", "<leader>qf", function()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      vim.cmd "cclose"
      return
    end
  end
  vim.cmd "copen"
end, opts "Toggle Quickfix")

-- Clear highlights
keymap("n", "<leader>hl", ":nohlsearch<CR>", opts "Clear highlights")

-- Increment/Decrement numbers
keymap("n", "a", "<C-a>", opts "Increment number")
keymap("n", "q", "<C-x>", opts "Decrement number")

-- Terminal Stuuf
keymap({ "n", "t" }, "<leader>tr", ":ToggleTerm<CR>", opts "Toggle terminal")
keymap({ "n", "t" }, "<leader>tg", ":ToggleLazygit<CR>", opts "Toggle lazygit")

-- Cword Replace
keymap("n", "<leader>sw", ":SwapNext<CR>", opts "Cword Replace, next")
keymap("n", "<leader>sW", ":SwapPrev<CR>", opts "Cword Replace, previous")
keymap("n", "<leader>sc", ":SwapCNext<CR>", opts "Case Replace, next")
keymap("n", "<leader>sC", ":SwapCPrev<CR>", opts "Case Replace, previous")
keymap("n", "<leader>sr", ":SwapReload<CR>", opts "Reload swap groups")

-- Insert --

-- Press jk fast to enter
keymap("i", "jk", "<Esc>", opt)

-- Visual --

-- Moving text around
keymap("v", "<", "<gv", opt)
keymap("v", ">", ">gv", opt)
keymap("v", "J", ":m '>+1<CR>gv=gv", opt)
keymap("v", "K", ":m '<-2<CR>gv=gv", opt)

-- Better paste
keymap("v", "p", "P", opt)
keymap("v", "P", '"_dP', opt)

-- Visual Block --

-- Better paste
keymap("x", "p", "P", opt)
keymap("x", "P", '"_dP', opt)

-- Terminal --

-- Better back to normal mode
keymap("t", "<Esc><Esc>", "<C-\\><C-n>", opts "Exit terminal to normal Mode")

---- Plugins ----

-- Normal --

-- end, opts "Comment multiline")
keymap("n", "<leader>tw", ":Trouble diagnostics toggle<CR>", opts "Open trouble workspace diagnostics")
keymap("n", "<leader>td", ":Trouble diagnostics toggle filter.buf=0<CR>", opts "Open trouble document diagnostics")
keymap("n", "<leader>tq", ":Trouble quickfix toggle<CR>", opts "Open trouble quickfix list")
keymap("n", "<leader>tl", ":Trouble loclist toggle<CR>", opts "Open trouble location list")
keymap("n", "<leader>tt", ":Trouble todo toggle<CR>", opts "Open todos in trouble")
keymap("n", "[t", function()
  require("trouble").next { skip_groups = true, jump = true }
end, opts "Next trouble")
keymap("n", "]t", function()
  require("trouble").previous { skip_groups = true, jump = true }
end, opts "Previous trouble")

-- Noice
keymap("n", "<leader>nh", ":NoiceDismiss<CR>", opts "Dimmis noice notifications")

-- Oil Nvim
keymap("n", "<leader>ee", ":Oil --float<CR>", opts "Toggles Oil")

-- Harpoon
keymap("n", "<leader>a", function()
  require("harpoon"):list():add()
end, opts "Marks a file")
keymap("n", "<leader>ha", function()
  require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
end, opts "Opens Harpoon Menu")
keymap("n", "<leader>1", function()
  require("harpoon"):list():select(1)
end, opts "Open file 1")
keymap("n", "<leader>2", function()
  require("harpoon"):list():select(2)
end, opts "Open file 2")
keymap("n", "<leader>3", function()
  require("harpoon"):list():select(3)
end, opts "Open file 3")
keymap("n", "<leader>4", function()
  require("harpoon"):list():select(4)
end, opts "Open file 4")
keymap("n", "<leader>5", function()
  require("harpoon"):list():select(5)
end, opts "Open file 5")

-- Comment
keymap("n", "<leader>/", function()
  require("Comment.api").toggle.linewise.current()
end, opts "Comments line")
keymap({ "x", "v" }, "<leader>/", "<Esc><:lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", opts "Comments multi-line")

-- Todo Comments
keymap("n", "<C-d>", function()
  require("todo-comments").jump_next()
end, opts "Next todo comment")
keymap("n", "<C-c>", function()
  require("todo-comments").jump_prev()
end, opts "Previous todo comment")

-- Nvim Ufo
keymap("n", "<leader>zr", function()
  require("ufo").openAllFolds()
end, opts "Opens all folds")
keymap("n", "<leader>zm", function()
  require("ufo").closeAllFolds()
end, opts "Closes all folds")
keymap("n", "<leader>zf", ":foldopen<CR>", opts "Opens folds")
keymap("n", "<leader>zc", ":foldclose<CR>", opts "Closes folds")
keymap("n", "<leader>zk", function()
  local winid = require("ufo").peekFoldedLinesUnderCursor()
  if not winid then
    vim.lsp.buf.hover()
  end
end, opts "Peek closed folds")

-- Telescope
keymap("n", "<leader>ff", ":Telescope find_files<CR>", opts "Fuzzy find files in cwd")
keymap("n", "<leader>fr", ":Telescope oldfiles<CR>", opts "Fuzzy find recent files")
keymap("n", "<leader>fs", ":Telescope live_grep<CR>", opts "Find string in cwd")
keymap("n", "<leader>fc", ":Telescope grep_string<CR>", opts "Find string under cursor in cwd")
keymap("n", "<leader>fb", ":Telescope buffers<CR>", opts "List active file buffers")
keymap("n", "<leader>fk", ":Telescope keymaps<CR>", opts "List keymaps")
keymap("n", "<leader>fh", ":Telescope help_tags<CR>", opts "Fuzzy find help pages")
keymap("n", "<leader>ft", ":TodoTelescope<CR>", opts "Find todos")

-- Formatter and Linters
keymap("n", "<leader>ml", function()
  require("lint").try_lint()
end, opts "Trigger linting for current file")
keymap({ "n", "v" }, "<leader>mf", function()
  require("conform").format {
    lsp_fallback = true,
    async = false,
    timeout_ms = 1000,
  }
end, opts "Format file or range (in visual mode)")

-- Lsp
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local lspopts = function(desc)
      return { desc = desc, buffer = bufnr, noremap = true, silent = true }
    end

    -- Keymaps for LSP
    keymap("n", "gR", ":Telescope lsp_references<CR>", lspopts "Show definition, references")
    keymap("n", "gD", function()
      vim.lsp.buf.declaration()
    end, lspopts "Go to declaration")
    keymap("n", "gd", ":Telescope lsp_definitions<CR>", lspopts "Show LSP definitions")
    keymap("n", "gi", ":Telescope lsp_implementations<CR>", lspopts "Show LSP implementations")
    keymap("n", "gt", ":Telescope lsp_type_definitions<CR>", lspopts "Show LSP type definitions")
    keymap({ "n", "v" }, "<leader>ca", function()
      vim.lsp.buf.code_action()
    end, lspopts "See available code actions; applies to selection in visual mode")
    keymap("n", "<leader>rn", function()
      vim.lsp.buf.rename()
    end, lspopts "Smart rename")
    keymap("n", "<leader>D", ":Telescope diagnostics bufnr=0<CR>", lspopts "Show diagnostics for file")
    keymap("n", "<leader>d", function()
      vim.diagnostic.open_float()
    end, lspopts "Show diagnostics for line")
    keymap("n", "[d", function()
      vim.diagnostic.goto_prev()
    end, lspopts "Jump to previous diagnostic in buffer")
    keymap("n", "]d", function()
      vim.diagnostic.goto_next()
    end, lspopts "Jump to next diagnostic in buffer")
    keymap("n", "gK", function()
      vim.lsp.buf.hover()
    end, lspopts "Show documentation for what is under cursor")
    keymap("n", "<leader>rs", ":LspRestart<CR>", lspopts "Restart LSP if necessary")

    vim.notify("Lsp Attached to: " .. vim.fn.expand "%:t", vim.log.levels.INFO)
  end,
})

-- Undotree
keymap("n", "<leader>u", function()
  require("undotree").toggle()
end, opts "Toggle undotree")

-- Insert mode

-- LuaSnip
keymap({ "i" }, "<C-K>", function()
  require("luasnip").expand()
end, opt)
keymap({ "i", "s" }, "<leader>.", function()
  require("luasnip").jump(1)
end, opts "Next snippet")
keymap({ "i", "s" }, "<leader>,", function()
  require("luasnip").jump(-1)
end, opts "Previous snippet")
keymap({ "i", "s" }, "<C-E>", function()
  if require("luasnip").choice_active() then
    require("luasnip").change_choice(1)
  end
end, opts "Next snippet choice")
