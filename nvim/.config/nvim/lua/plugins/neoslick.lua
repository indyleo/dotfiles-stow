return {
  {
    "karb94/neoscroll.nvim",
    opts = {},
    config = function()
      if vim.g.neovide then
        require("smear_cursor").enabled = false
      end
    end,
  },
  {
    "sphamba/smear-cursor.nvim",
    opts = {},
  },
}
