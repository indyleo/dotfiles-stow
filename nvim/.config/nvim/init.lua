-- Files
require "options"
if vim.g.neovide then
  require "guioptions"
end
require "keymaps"
require "autocommand"
require "config.Lazy"

vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
