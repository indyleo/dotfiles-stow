return {
  "jiaoshijie/undotree",
  dependencies = "nvim-lua/plenary.nvim",
  config = function()
    local undotree = require "undotree"
    undotree.setup()
  end,
}
