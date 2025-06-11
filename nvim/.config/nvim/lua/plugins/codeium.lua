return {
  "Exafunction/windsurf.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
  },
  config = function()
    local codeium = require "codeium"
    codeium.setup {
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        filetypes = {
          markdown = false,
          text = false,
          gitcommit = false,
          gitrebase = false,
          rust = false, -- Here because im learning rust
        },
        default_filetype_enabled = true,
        virtual_text_priority = 65535,
        map_keys = true,
        key_bindings = {
          accept = "<C-z>",
          clear = "<C-x>",
          next = "<C-l>",
          prev = "<C-h>",
        },
      },
    }
  end,
}
