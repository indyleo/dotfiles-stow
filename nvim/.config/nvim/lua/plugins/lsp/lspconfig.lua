return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
  },

  config = function()
    -- === Diagnostics setup ===
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    vim.diagnostic.config {
      virtual_text = true,
      signs = true,
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

    -- === LSP capabilities ===
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.foldingRange = { dynamicRegistration = true, lineFoldingOnly = true }
    capabilities.textDocument.semanticTokens.multilineTokenSupport = true
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -- === Default servers to loop through ===
    local default_servers = {
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
    }

    for _, server in ipairs(default_servers) do
      vim.lsp.config(server, { capabilities = capabilities })
    end

    -- === Server-specific configurations ===

    -- Lua LSP
    vim.lsp.config("lua-language-server", {
      capabilities = capabilities,
      settings = {
        Lua = {
          runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
          diagnostics = { globals = { "vim" } },
          workspace = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file("", true) },
          telemetry = { enable = false },
          completion = { callSnippet = "Replace" },
        },
      },
    })
  end,
}
