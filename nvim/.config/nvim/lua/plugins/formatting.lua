return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require "conform"

    conform.setup {
      formatters_by_ft = {
        -- Text
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier", "alex" },

        -- Web
        javascript = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },

        -- Langs
        lua = { "stylua" },
        python = { "isort", "black" },
        go = { "crlfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        cmake = { "cmakelang" },

        -- Script
        zsh = { "beautysh" },
        bash = { "shellharden", "beautysh" },
        sh = { "beautysh" },
      },
      format_on_save = {
        lsp_fallback = true,
        async = false,
        timeout_ms = 1000,
      },
    }
  end,
}
