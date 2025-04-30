return {
	"indyleo/fileutils-nvim",
	config = function()
		require("fileutils").setup()
	end,
	dependencies = {
		{
			"stevearc/oil.nvim",
			dependencies = {
				"nvim-tree/nvim-web-devicons",
			},
			lazy = false,
		},
	},
	-- { -- Here to test fileutils
	-- 	dir = "~/Github/fileutils-nvim",
	-- 	config = function()
	-- 		require("fileutils").setup()
	-- 	end,
	-- },
}
