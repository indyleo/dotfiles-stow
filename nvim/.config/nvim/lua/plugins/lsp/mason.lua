return {
  "williamboman/mason.nvim",
  dependencies = {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require "mason"
    local mason_tool_installer = require "mason-tool-installer"

    -- Mason UI
    mason.setup {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    }

    -- Ensure essential LSP servers and formatters/linters are installed
    mason_tool_installer.setup {
      ensure_installed = {
        -- Text
        "json-lsp",
        "yaml-language-server",
        "taplo",
        "ltex-ls",
        "alex",
        "codespell",

        -- Web
        "html-lsp",
        "css-lsp",
        "htmlhint",
        "eslint_d",
        "prettier",

        -- Languages
        "cmake-language-server",
        "checkmake",
        "pyright",
        "lua-language-server",
        "clangd",
        "rust-analyzer",
        "cmake-language-server",
        "bacon-ls",

        -- Script / Shell
        "bash-language-server",
        "shellcheck",

        -- Formatters / Linters
        "black",
        "isort",
        "pylint",
        "stylua",
      },
    }
  end,
}
