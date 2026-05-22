-- lua/config/pack.lua
-- Built-in plugin manager (Neovim 0.12+).
--
-- ┌─ COMMANDS ───────────────────────────────────────────────────────────────┐
-- │  :PackUpdate          – update all plugins (shows confirm buffer)        │
-- │  :PackUpdateForce     – update all plugins immediately, no confirm       │
-- │  :PackSync            – offline re-lock only (no network)                │
-- │  :PackStatus          – floating window: name │ rev │ active             │
-- │  :PackClean           – delete plugins removed from the spec list        │
-- │  :PackAdd <url>       – install a plugin from a URL right now            │
-- │  :PackDel <name>      – remove a plugin by name right now                │
-- │  :PackReinstall <name>– del + add in one shot (e.g. to switch branch)    │
-- │  :PackList            – print all plugin names to the command line        │
-- │  :PackLog             – tail the nvim-pack.log file                      │
-- │  :PackEdit            – open this file for editing                       │
-- └──────────────────────────────────────────────────────────────────────────┘

local gh = function(x)
  return "https://github.com/" .. x
end

-- ═══════════════════════════════════════════════════════════════════════════
-- §1  PackChanged hook  (build steps after install / update)
-- ═══════════════════════════════════════════════════════════════════════════

vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local name = ev.data.spec.name
    local kind = ev.data.kind -- "install" | "update" | "delete"

    -- nvim-treesitter: run parser install after install/update
    if name == "nvim-treesitter" and (kind == "install" or kind == "update") then
      vim.schedule(function()
        if not ev.data.active then
          vim.cmd.packadd "nvim-treesitter"
        end
        require("nvim-treesitter").update()
      end)
    end

    -- mason-tool-installer: trigger tool install after mason itself updates
    if name == "mason.nvim" and kind == "update" then
      vim.schedule(function()
        if not ev.data.active then
          vim.cmd.packadd "mason-tool-installer.nvim"
        end
        vim.cmd "MasonToolsInstall"
      end)
    end
  end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- §2  Plugin spec list
-- ═══════════════════════════════════════════════════════════════════════════

vim.pack.add {
  -- ── Completion ────────────────────────────────────────────────────────
  { src = gh "saghen/blink.cmp", name = "blink.cmp", version = vim.version.range "1.*" },
  { src = gh "rafamadriz/friendly-snippets", name = "friendly-snippets" },

  -- ── LSP ───────────────────────────────────────────────────────────────
  { src = gh "neovim/nvim-lspconfig", name = "nvim-lspconfig" },
  { src = gh "antosha417/nvim-lsp-file-operations", name = "nvim-lsp-file-operations" },
  { src = gh "williamboman/mason.nvim", name = "mason.nvim" },
  { src = gh "WhoIsSethDaniel/mason-tool-installer.nvim", name = "mason-tool-installer.nvim" },

  -- ── Treesitter ────────────────────────────────────────────────────────
  { src = gh "nvim-treesitter/nvim-treesitter", name = "nvim-treesitter" },

  -- ── Formatting & Linting ──────────────────────────────────────────────
  { src = gh "stevearc/conform.nvim", name = "conform.nvim" },
  { src = gh "mfussenegger/nvim-lint", name = "nvim-lint" },

  -- ── Fuzzy Finder ──────────────────────────────────────────────────────
  { src = gh "ibhagwan/fzf-lua", name = "fzf-lua" },
  { src = gh "nvim-tree/nvim-web-devicons", name = "nvim-web-devicons" },

  -- ── Git ───────────────────────────────────────────────────────────────
  { src = gh "lewis6991/gitsigns.nvim", name = "gitsigns.nvim" },

  -- ── UI & Notifications ────────────────────────────────────────────────
  { src = gh "folke/noice.nvim", name = "noice.nvim" },
  { src = gh "MunifTanjim/nui.nvim", name = "nui.nvim" },
  { src = gh "rcarriga/nvim-notify", name = "nvim-notify" },
  { src = gh "stevearc/dressing.nvim", name = "dressing.nvim" },

  -- ── Editing helpers ───────────────────────────────────────────────────
  { src = gh "windwp/nvim-autopairs", name = "nvim-autopairs" },
  { src = gh "kylechui/nvim-surround", name = "nvim-surround" },

  -- ── Navigation ────────────────────────────────────────────────────────
  { src = gh "ThePrimeagen/harpoon", name = "harpoon", version = "harpoon2" },
  { src = gh "nvim-lua/plenary.nvim", name = "plenary.nvim" },

  -- ── Motion ────────────────────────────────────────────────────────────
  { src = gh "karb94/neoscroll.nvim", name = "neoscroll.nvim" },
  { src = gh "sphamba/smear-cursor.nvim", name = "smear-cursor.nvim" },

  -- ── Markdown / Docs ───────────────────────────────────────────────────
  { src = gh "MeanderingProgrammer/render-markdown.nvim", name = "render-markdown.nvim" },
  { src = gh "3rd/image.nvim", name = "image.nvim" },
  { src = gh "aspeddro/slides.nvim", name = "slides.nvim" },

  -- ── Which-key ─────────────────────────────────────────────────────────
  { src = gh "folke/which-key.nvim", name = "which-key.nvim" },

  -- ── AI ────────────────────────────────────────────────────────────────
  { src = gh "Exafunction/windsurf.nvim", name = "windsurf.nvim" },

  -- ── Personal ──────────────────────────────────────────────────────────
  { src = gh "indyleo/sword-nvim", name = "sword-nvim" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- §3  Plugin loader helper
-- ═══════════════════════════════════════════════════════════════════════════

local function load(plugin_name, setup_fn)
  local ok, err = pcall(vim.cmd.packadd, plugin_name)
  if not ok then
    vim.notify("vim.pack: failed to load " .. plugin_name .. "\n" .. tostring(err), vim.log.levels.WARN)
    return
  end
  if setup_fn then
    local ok2, err2 = pcall(setup_fn)
    if not ok2 then
      vim.notify("vim.pack: setup error in " .. plugin_name .. "\n" .. tostring(err2), vim.log.levels.ERROR)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- §4  Plugin setup
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Foundational (no config) ────────────────────────────────────────────
load "plenary.nvim"
load "nvim-web-devicons"
load "nui.nvim"
load "friendly-snippets"

-- ── blink.cmp ───────────────────────────────────────────────────────────
load("blink.cmp", function()
  require("blink.cmp").setup {
    keymap = { preset = "default" },
    completion = { documentation = { auto_show = true } },
    signature = { enabled = true },
  }
end)

-- ── nvim-notify ─────────────────────────────────────────────────────────
load("nvim-notify", function()
  require("notify").setup {
    background_colour = "#1e1e1e",
    render = "compact",
    stages = "fade_in_slide_out",
    timeout = 3000,
    icons = { ERROR = " ", WARN = " ", INFO = " ", DEBUG = " ", TRACE = " " },
  }
  vim.notify = require "notify"
end)

-- ── noice.nvim ──────────────────────────────────────────────────────────
load("noice.nvim", function()
  if vim.o.filetype == "lazy" then
    vim.cmd [[messages clear]]
  end
  require("noice").setup {
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    routes = {
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "%d+L, %d+B" },
            { find = "; after #%d+" },
            { find = "; before #%d+" },
          },
        },
        view = "mini",
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
    },
  }
  local k = vim.keymap.set
  k("c", "<S-Enter>", function()
    require("noice").redirect(vim.fn.getcmdline())
  end, { desc = "Redirect Cmdline" })
  k("n", "<leader>snl", function()
    require("noice").cmd "last"
  end, { desc = "Noice Last Message" })
  k("n", "<leader>snh", function()
    require("noice").cmd "history"
  end, { desc = "Noice History" })
  k("n", "<leader>sna", function()
    require("noice").cmd "all"
  end, { desc = "Noice All" })
  k("n", "<leader>snd", function()
    require("noice").cmd "dismiss"
  end, { desc = "Dismiss All" })
  k({ "i", "n", "s" }, "<c-f>", function()
    if not require("noice.lsp").scroll(4) then
      return "<c-f>"
    end
  end, { silent = true, expr = true, desc = "Scroll Forward" })
  k({ "i", "n", "s" }, "<c-b>", function()
    if not require("noice.lsp").scroll(-4) then
      return "<c-b>"
    end
  end, { silent = true, expr = true, desc = "Scroll Backward" })
end)

-- ── dressing.nvim ───────────────────────────────────────────────────────
load("dressing.nvim", function()
  require("dressing").setup {}
end)

-- ── nvim-treesitter ─────────────────────────────────────────────────────
load("nvim-treesitter", function()
  local install_dir = vim.fn.stdpath "data" .. "/site"
  require("nvim-treesitter").setup { install_dir = install_dir }
  require("nvim-treesitter").install {
    "json",
    "yaml",
    "toml",
    "gitignore",
    "markdown",
    "markdown_inline",
    "qmljs",
    "qmldir",
    "regex",
    "git_config",
    "gitcommit",
    "git_rebase",
    "gitattributes",
    "cmake",
    "html",
    "css",
    "javascript",
    "tsx",
    "sql",
    "bash",
    "fish",
    "powershell",
    "python",
    "lua",
    "go",
    "gomod",
    "gowork",
    "gosum",
    "rust",
    "ron",
    "zig",
    "c",
    "cpp",
    "vim",
    "vimdoc",
    "arduino",
  }
end)

-- ── mason.nvim ──────────────────────────────────────────────────────────
load("mason.nvim", function()
  require("mason").setup {
    ui = { icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" } },
  }
end)

load("mason-tool-installer.nvim", function()
  require("mason-tool-installer").setup {
    ensure_installed = {
      "jsonlint",
      "json-lsp",
      "alex",
      "taplo",
      "yamllint",
      "yaml-language-server",
      "eslint_d",
      "htmlhint",
      "stylelint",
      "css-lsp",
      "eslint-lsp",
      "html-lsp",
      "htmx-lsp",
      "bacon",
      "black",
      "pyright",
      "cmakelang",
      "cmakelint",
      "checkmake",
      "cpplint",
      "clang-format",
      "clangd",
      "isort",
      "prettier",
      "pylint",
      "rust-analyzer",
      -- NOTE: rustfmt is not a Mason package; install it via rustup: `rustup component add rustfmt`
      "selene",
      "stylua",
      "emmylua_ls",
      "luau-lsp",
      "crlfmt",
      "staticcheck",
      "gopls",
      "bash-language-server",
      "beautysh",
      "shellcheck",
      "shellharden",
    },
    auto_update = true,
  }
end)

-- ── nvim-lspconfig ──────────────────────────────────────────────────────
load "nvim-lsp-file-operations"
load("nvim-lspconfig", function()
  vim.diagnostic.config {
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "",
        [vim.diagnostic.severity.WARN] = "",
        [vim.diagnostic.severity.HINT] = "󰠠",
        [vim.diagnostic.severity.INFO] = "",
      },
    },
    update_in_insert = true,
    underline = true,
    severity_sort = true,
    float = { focusable = false, style = "minimal", border = "single", source = "always" },
  }

  local caps = require("blink.cmp").get_lsp_capabilities(vim.lsp.protocol.make_client_capabilities())
  caps.textDocument.foldingRange = { dynamicRegistration = true, lineFoldingOnly = true }
  caps.textDocument.semanticTokens = caps.textDocument.semanticTokens or {}
  caps.textDocument.semanticTokens.multilineTokenSupport = true
  caps.textDocument.completion.completionItem.snippetSupport = true

  local servers = {
    "jsonls",
    "ltex",
    "taplo",
    "yamlls",
    "cssls",
    "eslint",
    "html",
    "htmx",
    "clangd",
    "pyright",
    "rust_analyzer",
    "bashls",
    "emmylua_ls",
    "luau_lsp",
    "gopls",
  }
  for _, s in ipairs(servers) do
    vim.lsp.config[s] = { default_config = { capabilities = caps } }
  end
  for _, s in ipairs(servers) do
    vim.lsp.enable(s)
  end
end)

-- ── conform.nvim ────────────────────────────────────────────────────────
load("conform.nvim", function()
  require("conform").setup {
    formatters_by_ft = {
      json = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier", "alex" },
      javascript = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      lua = { "stylua" },
      python = { "isort", "black" },
      go = { "crlfmt" },
      c = { "clang-format" },
      cpp = { "clang-format" },
      cmake = { "cmakelang" },
      zsh = { "beautysh" },
      bash = { "shellharden", "beautysh" },
      sh = { "beautysh" },
    },
    format_on_save = { lsp_fallback = true, async = false, timeout_ms = 1000 },
  }
end)

-- ── nvim-lint ───────────────────────────────────────────────────────────
load("nvim-lint", function()
  local lint = require "lint"
  lint.linters_by_ft = {
    markdown = { "alex" },
    json = { "jsonlint" },
    yaml = { "yamllint" },
    javascript = { "eslint_d" },
    typescript = { "eslint_d" },
    html = { "htmlhint" },
    css = { "stylelint" },
    python = { "pylint" },
    lua = { "luacheck" },
    go = { "staticcheck" },
    cpp = { "cpplint" },
    c = { "cpplint" },
    cmake = { "cmakelint" },
    make = { "checkmake" },
    bash = { "bash" },
    dash = { "dash" },
    zsh = { "zsh" },
    ShellCheck = { "shellcheck" },
    ["*"] = { "codespell" },
  }
  local lg = vim.api.nvim_create_augroup("lint", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    group = lg,
    callback = function()
      lint.try_lint()
    end,
  })
end)

-- ── fzf-lua ─────────────────────────────────────────────────────────────
load("fzf-lua", function()
  require("fzf-lua").setup {
    fzf_opts = { ["--ansi"] = true, ["--tabstop"] = "2" },
    file_icon_padding = " ",
    winopts = { split = "belowright 15new" },
  }
end)

-- ── gitsigns.nvim ───────────────────────────────────────────────────────
load("gitsigns.nvim", function()
  require("gitsigns").setup {
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      map("n", "]h", gs.next_hunk, "Next Hunk")
      map("n", "[h", gs.prev_hunk, "Prev Hunk")
      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk { vim.fn.line ".", vim.fn.line "v" }
      end, "Stage hunk")
      map("v", "<leader>hr", function()
        gs.reset_hunk { vim.fn.line ".", vim.fn.line "v" }
      end, "Reset hunk")
      map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>hb", function()
        gs.blame_line { full = true }
      end, "Blame line")
      map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")
      map("n", "<leader>hd", gs.diffthis, "Diff this")
      map("n", "<leader>hD", function()
        gs.diffthis "~"
      end, "Diff this ~")
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
    end,
  }
end)

-- ── harpoon ─────────────────────────────────────────────────────────────
load("harpoon", function()
  require("harpoon"):setup()
end)

-- ── nvim-autopairs ──────────────────────────────────────────────────────
load("nvim-autopairs", function()
  require("nvim-autopairs").setup {
    check_ts = true,
    ts_config = { lua = { "string" }, javascript = { "template_string" }, java = false },
  }
end)

-- ── nvim-surround ───────────────────────────────────────────────────────
load("nvim-surround", function()
  require("nvim-surround").setup {}
end)

-- ── neoscroll + smear-cursor ────────────────────────────────────────────
load("neoscroll.nvim", function()
  require("neoscroll").setup {}
  if vim.g.neovide then
    require("smear_cursor").enabled = false
  end
end)

load("smear-cursor.nvim", function()
  require("smear_cursor").setup {
    stiffness = 0.5,
    trailing_stiffness = 0.5,
    matrix_pixel_threshold = 0.5,
  }
end)

-- ── render-markdown ─────────────────────────────────────────────────────
load("render-markdown.nvim", function()
  require("render-markdown").setup {}
end)

-- ── image.nvim ──────────────────────────────────────────────────────────
load("image.nvim", function()
  require("image").setup {
    backend = "sixel",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = true,
        only_render_image_at_cursor_mode = "popup",
        filetypes = { "markdown", "vimwiki" },
      },
    },
    max_height_window_percentage = 50,
    kitty_method = "normal",
  }
end)

-- ── slides.nvim ─────────────────────────────────────────────────────────
load("slides.nvim", function()
  require("slides").setup {}
end)

-- ── which-key ───────────────────────────────────────────────────────────
load("which-key.nvim", function()
  vim.o.timeout = true
  vim.o.timeoutlen = 500
  require("which-key").setup {}
end)

-- ── windsurf (codeium) ──────────────────────────────────────────────────
load("windsurf.nvim", function()
  require("codeium").setup {
    enable_cmp_source = false,
    virtual_text = {
      enabled = true,
      filetypes = { markdown = false, text = false, gitcommit = false, gitrebase = false, rust = false },
      default_filetype_enabled = true,
      virtual_text_priority = 65535,
      map_keys = true,
      key_bindings = { accept = "<C-z>", clear = "<C-x>", next = "<C-l>", prev = "<C-h>" },
    },
  }
end)

-- ── sword-nvim ──────────────────────────────────────────────────────────
load("sword-nvim", function()
  require("sword").setup {
    popup_timeout = 1000,
    mappings = true,
    custom_groups = { { "foo", "bar", "baz" } },
  }
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- §5  User commands
-- ═══════════════════════════════════════════════════════════════════════════

local cmd = vim.api.nvim_create_user_command

-- :PackUpdate — interactive update (shows confirm buffer; :w to apply, :q to skip)
cmd("PackUpdate", function()
  vim.pack.update()
end, { desc = "Update all plugins (interactive confirm buffer)" })

-- :PackUpdateForce — pull + apply immediately, no confirm buffer
cmd("PackUpdateForce", function()
  vim.pack.update(nil, { force = true })
  vim.notify("All plugins updated.", vim.log.levels.INFO)
end, { desc = "Update all plugins immediately (no confirm)" })

-- :PackSync — re-lock from lockfile only, no network
cmd("PackSync", function()
  vim.pack.update(nil, { offline = true, target = "lockfile" })
end, { desc = "Re-sync plugins from lockfile (offline)" })

-- :PackStatus — floating window showing each plugin's name, rev, and active state
cmd("PackStatus", function()
  local plugins = vim.pack.get()
  table.sort(plugins, function(a, b)
    return a.spec.name < b.spec.name
  end)

  local lines = { "  Plugin                             Rev       Active" }
  local sep = "  " .. string.rep("─", 54)
  table.insert(lines, sep)

  for _, p in ipairs(plugins) do
    local active = p.active and "✓" or "·"
    local rev = (p.rev or "?"):sub(1, 8)
    table.insert(lines, string.format("  %-34s %-9s %s", p.spec.name, rev, active))
  end

  table.insert(lines, sep)
  table.insert(lines, string.format("  %d plugin(s) total", #plugins))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local w = 62
  local h = math.min(#lines, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
    border = "rounded",
    style = "minimal",
    title = " Pack Status ",
    title_pos = "center",
  })
  vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = win })

  -- Highlight header
  local ns = vim.api.nvim_create_namespace "pack_status"
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", #lines - 1, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Comment", #lines, 0, -1)

  -- Colour active vs inactive rows
  for i, p in ipairs(plugins) do
    local hl = p.active and "DiagnosticOk" or "Comment"
    vim.api.nvim_buf_add_highlight(buf, ns, hl, i + 1, 0, -1)
  end

  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true, nowait = true })
  end
end, { desc = "Show plugin status in a floating window" })

-- :PackClean — delete plugins that are on disk but no longer in the spec
cmd("PackClean", function()
  local inactive = vim
    .iter(vim.pack.get())
    :filter(function(x)
      return not x.active
    end)
    :map(function(x)
      return x.spec.name
    end)
    :totable()

  if #inactive == 0 then
    vim.notify("Nothing to clean — all managed plugins are active.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(
    vim.list_extend({ "Delete all (" .. #inactive .. ")" }, inactive),
    { prompt = "PackClean: select plugin to delete, or delete all" },
    function(choice)
      if not choice then
        return
      end
      if choice:match "^Delete all" then
        vim.pack.del(inactive)
        vim.notify("Deleted " .. #inactive .. " unused plugin(s).", vim.log.levels.INFO)
      else
        vim.pack.del { choice }
        vim.notify("Deleted: " .. choice, vim.log.levels.INFO)
      end
    end
  )
end, { desc = "Delete plugins that are no longer in the spec" })

-- :PackAdd <url> [name] — install a new plugin immediately without editing this file
cmd("PackAdd", function(o)
  local args = vim.split(o.args, "%s+", { trimempty = true })
  local src = args[1]
  local name = args[2]
  if not src or src == "" then
    vim.notify("Usage: PackAdd <url> [name]", vim.log.levels.WARN)
    return
  end
  local spec = name and { src = src, name = name } or { src = src }
  vim.pack.add { spec }
  vim.notify("Added " .. (name or src) .. ". Run :restart to load it.", vim.log.levels.INFO)
end, {
  nargs = "+",
  desc = "Add and install a plugin from a URL",
})

-- :PackDel <name> — remove a plugin by name
cmd("PackDel", function(o)
  local name = vim.trim(o.args)
  if name == "" then
    vim.notify("Usage: PackDel <plugin-name>", vim.log.levels.WARN)
    return
  end
  vim.pack.del { name }
  vim.notify("Deleted plugin: " .. name, vim.log.levels.INFO)
end, {
  nargs = 1,
  complete = function()
    return vim
      .iter(vim.pack.get())
      :map(function(x)
        return x.spec.name
      end)
      :totable()
  end,
  desc = "Delete a managed plugin by name",
})

-- :PackReinstall <name> — del + re-add in one shot (useful for branch switches)
cmd("PackReinstall", function(o)
  local name = vim.trim(o.args)
  if name == "" then
    vim.notify("Usage: PackReinstall <plugin-name>", vim.log.levels.WARN)
    return
  end
  -- Find the existing spec so we can re-add with the same source
  local info = vim.iter(vim.pack.get { name }):next()
  if not info then
    vim.notify("Plugin not found: " .. name, vim.log.levels.ERROR)
    return
  end
  vim.pack.del { name }
  vim.pack.add { info.spec }
  vim.notify("Reinstalling " .. name .. ". Run :restart to load it.", vim.log.levels.INFO)
end, {
  nargs = 1,
  complete = function()
    return vim
      .iter(vim.pack.get())
      :map(function(x)
        return x.spec.name
      end)
      :totable()
  end,
  desc = "Reinstall a plugin (del + add) — useful after changing version/src",
})

-- :PackList — print all managed plugin names to the command line
cmd("PackList", function()
  local plugins = vim.pack.get()
  table.sort(plugins, function(a, b)
    return a.spec.name < b.spec.name
  end)
  local lines = {}
  for i, p in ipairs(plugins) do
    local active = p.active and "+" or "-"
    table.insert(lines, string.format(" %2d  [%s]  %s", i, active, p.spec.name))
  end
  vim.api.nvim_echo(
    vim
      .iter(lines)
      :map(function(l)
        return { l .. "\n", "Normal" }
      end)
      :totable(),
    true,
    {}
  )
end, { desc = "List all managed plugins ([+] active, [-] inactive)" })

-- :PackLog — tail the nvim-pack.log in a split
cmd("PackLog", function()
  local log = vim.fn.stdpath "log" .. "/nvim-pack.log"
  if vim.fn.filereadable(log) == 0 then
    vim.notify("No pack log found at: " .. log, vim.log.levels.WARN)
    return
  end
  vim.cmd("botright 16split " .. vim.fn.fnameescape(log))
  vim.cmd "normal! G" -- jump to end
  vim.api.nvim_set_option_value("modifiable", false, { buf = 0 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
end, { desc = "Open the nvim-pack update log" })

-- :PackEdit — open this file for editing
cmd("PackEdit", function()
  vim.cmd("edit " .. vim.fn.fnameescape(debug.getinfo(1, "S").source:sub(2)))
end, { desc = "Open lua/config/pack.lua for editing" })
