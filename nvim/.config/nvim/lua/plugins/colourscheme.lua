local cache_home = os.getenv "XDG_CACHE_HOME" or os.getenv "HOME" .. "/.cache"
local theme_file = cache_home .. "/theme"

local function read_theme(path)
  local f = io.open(path, "r")
  if f then
    local theme = f:read "*l"
    f:close()
    return theme
  end
  return nil
end

local theme_current = read_theme(theme_file) or "gruvbox"

return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      if theme_current == "gruvbox" then
        require("gruvbox").setup {
          transparent_mode = not vim.g.neovide,
        }
        vim.cmd.colorscheme "gruvbox"
      end
    end,
  },
  {
    "gbprod/nord.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      if theme_current == "nord" then
        require("nord").setup {
          transparent = not vim.g.neovide,
        }
        vim.cmd.colorscheme "nord"
      end
    end,
  },
}
