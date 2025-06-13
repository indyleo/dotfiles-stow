return {
  "indyleo/fileutils-nvim",
  dependencies = {
    {
      "stevearc/oil.nvim",
      dependencies = {
        "nvim-tree/nvim-web-devicons",
      },
      lazy = false,
    },
  },
  lazy = false,
  config = function()
    require("fileutils").setup()
  end,
  -- { -- Here to test fileutils
  --   dir = "~/Github/fileutils-nvim",
  --   lazy = false,
  --   config = function()
  --     require("fileutils").setup()
  --   end,
  -- },
}
