return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  install_dir = vim.fn.stdpath "data" .. "/site",
  config = function()
    require("nvim-treesitter").setup {
      -- Directory to install parsers and queries to (prepended to `runtimepath` to have priority)
      install_dir = vim.fn.stdpath "data" .. "/site",
    }
    require("nvim-treesitter").install {
      -- Text
      "json",
      "yaml",
      "toml",
      "gitignore",
      "markdown",
      "markdown_inline",
      "regex",
      "git_config",
      "gitcommit",
      "git_rebase",
      "gitignore",
      "gitattributes",
      "cmake",
      -- Web
      "html",
      "css",
      "javascript",
      "tsx",
      "sql",
      -- Shell
      "bash",
      "fish",
      "powershell",
      -- Langs
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
  end,
}
