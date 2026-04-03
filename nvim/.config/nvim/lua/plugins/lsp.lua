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
      local capabilities = require("blink.cmp").get_lsp_capabilities(vim.lsp.protocol.make_client_capabilities())
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
        "pyright",
        "rust_analyzer",
        "bashls",
        "emmylua_ls",
        "luau_lsp",
        "gopls",
      }

      local lspconfig = vim.lsp.config

      for _, server in ipairs(servers) do
        local default_config = {
          capabilities = capabilities,
        }

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
          "jsonlint",
          "json-lsp",
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
          "cpplint",
          "clang-format",
          "clangd",
          "isort",
          "prettier",
          "pylint",
          "rustfmt",
          "rust-analyzer",
          "selene",
          "stylua",
          "emmylua_ls",
          "luau-lsp",
          "crlfmt",
          "staticcheck",
          "gopls",
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
