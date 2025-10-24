return {
  -- LSPConfig
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      { "antosha417/nvim-lsp-file-operations", config = true },
      {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
          librarys = {
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
          },
        },
      },
    },
    config = function()
      -- Diagnostics config
      vim.diagnostic.config {
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.HINT] = "",
            [vim.diagnostic.severity.INFO] = "",
          },
        },
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        float = { focusable = false, style = "minimal", border = "single", source = "always" },
      }

      -- Diagnostic signs
      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        vim.fn.sign_define("DiagnosticSign" .. type, { text = icon, texthl = "DiagnosticSign" .. type })
      end

      -- Capabilities
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.foldingRange = { dynamicRegistration = true, lineFoldingOnly = true }
      capabilities.textDocument.semanticTokens.multilineTokenSupport = true
      capabilities.textDocument.completion.completionItem.snippetSupport = true

      -- LSP servers list
      local servers = {
        "jsonls",
        "ltex",
        "taplo",
        "yamlls",
        "cssls",
        "eslint",
        "html",
        "clangd",
        "cmake",
        "lua_ls",
        "pyright",
        "rust_analyzer",
        "bashls",
      }

      -- New API: vim.lsp.config
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

        -- Register the server using the new API
        lspconfig[server] = {
          default_config = default_config,
        }
      end
    end,
  },

  -- Mason + Mason Tool Installer
  {
    "williamboman/mason.nvim",
    dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
    config = function()
      local mason = require "mason"
      local mason_tool_installer = require "mason-tool-installer"

      mason.setup {
        ui = { icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" } },
      }

      mason_tool_installer.setup {
        ensure_installed = {
          -- Text
          "codespell",
          "jsonlint",
          "alex",
          "yamllint",
          -- Web
          "eslint_d",
          "htmlhint",
          "stylelint",
          -- Languages
          "bacon",
          "black",
          "cmakelang",
          "cmakelint",
          "checkmake",
          "clang-format",
          "isort",
          "prettier",
          "pylint",
          "rustfmt",
          "selene",
          "stylua",
          -- Script/Shell
          "beautysh",
          "shellcheck",
          "shellharden",
        },
        auto_update = true,
      }
    end,
  },
}
