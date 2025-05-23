return {
  "gbprod/nord.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    if vim.g.neovide then
      require("nord").setup {
        transparent = false,
      }
    else
      require("nord").setup {
        transparent = true,
      }
    end
    vim.cmd.colorscheme "nord"
  end,
}
