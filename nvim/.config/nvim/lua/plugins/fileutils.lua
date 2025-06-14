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
  config = true,
  -- { -- Here to test fileutils
  --   dir = "~/Github/fileutils-nvim",
  --   lazy = false,
  --   config = true,
  -- },
}
