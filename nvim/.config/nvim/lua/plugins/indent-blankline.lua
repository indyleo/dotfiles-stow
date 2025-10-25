-- Get cache directory
local cache_home = os.getenv "XDG_CACHE_HOME" or os.getenv "HOME" .. "/.cache"
local theme_file = cache_home .. "/theme"

-- Function to read the theme from file
local function read_theme(path)
  local f = io.open(path, "r")
  if f then
    local theme = f:read "*l"
    f:close()
    return theme
  end
  return nil
end

-- Pull theme from file or fallback
local theme_current = read_theme(theme_file) or "gruvbox"

return {
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPre", "BufNewFile" },
    main = "ibl",
    config = function()
      local hooks = require "ibl.hooks"

      -- Theme-based highlights
      local highlights = {
        gruvbox = {
          RainbowRed = "#fb4934",
          RainbowYellow = "#fabd2f",
          RainbowBlue = "#83a598",
          RainbowOrange = "#fe8019",
          RainbowGreen = "#b8bb26",
          RainbowViolet = "#d3869b",
          RainbowCyan = "#8ec07c",
          ContextChar = "#7c6f64",
        },
        nord = {
          RainbowRed = "#BF616A",
          RainbowYellow = "#EBCB8B",
          RainbowBlue = "#81A1C1",
          RainbowOrange = "#D08770",
          RainbowGreen = "#A3BE8C",
          RainbowViolet = "#B48EAD",
          RainbowCyan = "#88C0D0",
          ContextChar = "#808080",
        },
      }

      -- Select the current theme's colors
      local theme_colors = highlights[theme_current] or highlights["gruvbox"]

      -- Register hook for custom highlights
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        for name, color in pairs(theme_colors) do
          if name == "ContextChar" then
            vim.api.nvim_set_hl(0, "IndentBlanklineContextChar", { fg = color })
          else
            vim.api.nvim_set_hl(0, name, { fg = color })
          end
        end
      end)

      -- Setup ibl
      require("ibl").setup {
        indent = {
          char = "▎",
          highlight = {
            "RainbowRed",
            "RainbowYellow",
            "RainbowBlue",
            "RainbowOrange",
            "RainbowGreen",
            "RainbowViolet",
            "RainbowCyan",
          },
        },
        scope = {
          char = "▎",
          highlight = "IndentBlanklineContextChar",
        },
      }
    end,
  },
}
