-- Files
require("options")
if vim.g.neovide then
	require("guioptions")
end
require("keymaps")
require("autocommand")
require("config.Lazy")

-- Directories
require("function")
