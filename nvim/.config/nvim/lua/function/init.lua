-- Files
local Fheader = require("function.FileHeader")
local Ffilehelper = require("function.FileHelper")
local Fcodeblock = require("function.CodeBlockToFile")

-- Commands

-- Markdown
vim.api.nvim_create_user_command("MarkdownCode", function()
	Fcodeblock.extract_code_blocks()
end, {})

-- File
vim.api.nvim_create_user_command("OilDir", function()
	Ffilehelper.OilDir()
end, {
	nargs = 1,
	complete = "file",
})

vim.api.nvim_create_user_command("EditFile", function()
	Ffilehelper.EditFile()
end, {
	nargs = "+",
	complete = "file",
})

vim.api.nvim_create_user_command("AskNewFileName", function()
	Ffilehelper.AskNewFileName()
end, { nargs = 0 })

vim.api.nvim_create_user_command("NewHSplit", function()
	Ffilehelper.NewHSplit()
end, { nargs = 0 })
vim.api.nvim_create_user_command("NewVSplit", function()
	Ffilehelper.NewVSplit()
end, { nargs = 0 })

-- Header
vim.api.nvim_create_user_command("FileHeader", function()
	Fheader.InsertFileHeader()
end, { nargs = 0 })
