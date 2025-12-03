return {
  "indyleo/sword-nvim",
  lazy = false,
  config = function()
    require("sword").setup {
      popup_timeout = 1000, -- Popup display duration in ms
      mappings = true, -- Enable default keymappings
      custom_groups = { -- Add your own swap groups
        { "foo", "bar", "baz" },
        { "public", "private", "protected" },
      },
    }
  end,
  --[[

  { -- Here to test sword
    dir = "~/Github/sword-nvim",
    lazy = false,
    config = function()
      require("sword").setup {
        popup_timeout = 1000, -- Popup display duration in ms
        mappings = true, -- Enable default keymappings
        custom_groups = { -- Add your own swap groups
          { "foo", "bar", "baz" },
          { "public", "private", "protected" },
        },
      }
    end,
  },

  ]]
  --
}
