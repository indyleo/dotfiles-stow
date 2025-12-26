return {
  "shaunsingh/nord.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("nord").setup {
      transparent = not vim.g.neovide,
    }
    vim.cmd.colorscheme "nord"
  end,
}
