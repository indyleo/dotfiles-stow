require("vim._core.ui2").enable {}
require "options"
if vim.g.neovide then
  require "guioptions"
end
require "keymaps"
require "autocommand"
require "config.pack"
