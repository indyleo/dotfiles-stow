return {
  -- 🌐 Core LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "antosha417/nvim-lsp-file-operations", config = true },
    },
    config = function()
      --------------------------------------------------------------------------
      -- 🩺 Diagnostics Configuration
      --------------------------------------------------------------------------
      vim.diagnostic.config {
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.HINT] = "󰠠",
            [vim.diagnostic.severity.INFO] = "",
          },
        },
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        float = {
          focusable = false,
          style = "minimal",
          border = "single",
          source = "always",
        },
      }

      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        vim.fn.sign_define("DiagnosticSign" .. type, { text = icon, texthl = "DiagnosticSign" .. type })
      end

      --------------------------------------------------------------------------
      -- ⚙️ Capabilities
      --------------------------------------------------------------------------
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.foldingRange = { dynamicRegistration = true, lineFoldingOnly = true }
      capabilities.textDocument.semanticTokens = capabilities.textDocument.semanticTokens or {}
      capabilities.textDocument.semanticTokens.multilineTokenSupport = true
      capabilities.textDocument.completion.completionItem.snippetSupport = true

      --------------------------------------------------------------------------
      -- 🔧 Servers
      --------------------------------------------------------------------------
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
        "cmake",
        "lua_ls",
        "pyright",
        "rust_analyzer",
        "bashls",
        "luau-lsp",
      }

      local lspconfig = vim.lsp.config

      for _, server in ipairs(servers) do
        local default_config = {
          capabilities = capabilities,
        }

        if server == "lua_ls" then
          default_config.settings = {
            Lua = {
              runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
              diagnostics = { globals = { "vim" } },
              workspace = {
                checkThirdParty = false,
                library = { vim.api.nvim_get_runtime_file("", true), vim.env.VIMRUNTIME },
              },
              telemetry = { enable = false },
              completion = { callSnippet = "Replace" },
            },
          }
        end

        -- 🧱 Declarative registration
        lspconfig[server] = { default_config = default_config }
      end

      --------------------------------------------------------------------------
      -- 🚀 Enable servers after defining configs
      --------------------------------------------------------------------------
      for _, server in ipairs(servers) do
        vim.lsp.enable(server)
      end
    end,
  },

  -- 🧰 Mason + Mason Tool Installer
  {
    "williamboman/mason.nvim",
    dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
    config = function()
      local mason = require "mason"
      local mason_tool_installer = require "mason-tool-installer"

      mason.setup {
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      }

      mason_tool_installer.setup {
        ensure_installed = {
          -- Text
          "codespell",
          "jsonlint",
          "json-lsp",
          "ltex-ls",
          "alex",
          "taplo",
          "yamllint",
          "yaml-language-server",
          -- Web
          "eslint_d",
          "htmlhint",
          "stylelint",
          "css-lsp",
          "eslint-lsp",
          "html-lsp",
          "htmx-lsp",
          -- Languages
          "bacon",
          "black",
          "pyright",
          "cmakelang",
          "cmakelint",
          "checkmake",
          "clang-format",
          "clangd",
          "cmake-language-server",
          "isort",
          "prettier",
          "pylint",
          "rustfmt",
          "selene",
          "stylua",
          "lua-language-server",
          "luau-lsp",
          -- Script / Shell
          "bash-language-server",
          "beautysh",
          "shellcheck",
          "shellharden",
        },
        auto_update = true,
      }
    end,
  },
}
