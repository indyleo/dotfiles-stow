return {
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
    -- import lspconfig plugin
    local lspconfig = require "lspconfig"

    -- import cmp-nvim-lsp plugin
    local cmp_nvim_lsp = require "cmp_nvim_lsp"

    -- used to enable autocompletion (assign to every lsp server config)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- Add custom folding range capabilities
    capabilities.textDocument = {
      foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      },
    }

    -- Change the Diagnostic symbols in the sign column (gutter)
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    lspconfig.lua_ls.setup {
      capabilities = capabilities,
      settings = {
        Lua = {
          runtime = {
            version = "LuaJIT", -- Neovim uses LuaJIT
            path = vim.split(package.path, ";"),
          },
          diagnostics = {
            globals = { "vim" }, -- recognize `vim` as a global
          },
          workspace = {
            checkThirdParty = false, -- avoid annoying prompts
            library = {
              vim.api.nvim_get_runtime_file("", true), -- include Neovim runtime files
              vim.env.VIMRUNTIME,
            },
          },
          telemetry = {
            enable = false, -- disable telemetry
          },
          completion = {
            callSnippet = "Replace",
          },
        },
      },
    }
    lspconfig.svelte.setup {
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = { "*.js", "*.ts" },
          callback = function(ctx)
            client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
          end,
        })
      end,
    }
    lspconfig.emmet_ls.setup {
      capabilities = capabilities,
      filetypes = {
        "html",
        "typescriptreact",
        "javascriptreact",
        "css",
        "sass",
        "scss",
        "less",
        "svelte",
      },
    }
    lspconfig["powershell_es"].setup {
      capabilities = capabilities,
      filetypes = { "ps1" },
      shell = "pwsh",
      bundle_path = vim.fn.stdpath "data" .. "/mason/packages/powershell-editor-services",
    }
  end,
}
