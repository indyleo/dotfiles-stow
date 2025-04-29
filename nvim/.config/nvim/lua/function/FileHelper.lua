-- lua/function/FileHelper.lua

local M = {}

-- Cd into dir and open Oil in that dir
function M.OilDir(opts)
	local path = opts.args -- Get the path argument
	local dirpath = path:gsub("\\", "/") .. "/" -- Normalize path
	vim.cmd("cd " .. vim.fn.fnameescape(dirpath)) -- Change directory
	vim.cmd("Oil --float") -- Open Oil in float mode
end

-- Function to cd into a directory and open a file
function M.EditFile(opts)
	local args = vim.split(opts.args, " ") -- Split arguments into dirpath and filename
	if #args < 2 then
		vim.api.nvim_err_writeln("Usage: :EditFile <dirpath> <filename>")
		return
	end

	local dirpath = args[1] -- First argument is the directory path
	local filename = args[2] -- Second argument is the file name
	local escaped_dirpath = dirpath:gsub("\\", "/") .. "/"
	local filepath = escaped_dirpath .. filename

	-- Change directory
	vim.cmd("cd " .. vim.fn.fnameescape(escaped_dirpath))

	-- Open the file
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

-- Function to ask for a new file name and open it
M.AskNewFileName = function()
	local current_dir = vim.fn.getcwd() -- Get the current working directory
	vim.ui.input({ prompt = "Enter new file name: " }, function(filename)
		if filename ~= nil and filename ~= "" then
			local filepath = current_dir .. "/" .. filename
			vim.cmd("edit " .. vim.fn.fnameescape(filepath)) -- Open the new file
		else
			vim.notify("No file created", vim.log.levels.ERROR) -- Notify if no file is created
		end
	end)
end

-- Ask what file to open then opens it in a horizontal split
M.NewHSplit = function()
	local current_dir = vim.fn.getcwd()
	vim.ui.input({ prompt = "Enter file path: " }, function(input)
		if input and input ~= "" then
			local filepath = vim.fs.joinpath(current_dir, input)
			if vim.fn.filereadable(filepath) == 1 then
				vim.cmd("split " .. vim.fn.fnameescape(filepath))
			else
				vim.notify("File does not exist: " .. filepath, vim.log.levels.ERROR)
			end
		else
			vim.notify("No file provided.", vim.log.levels.WARN)
		end
	end)
end

-- Ask what file to open then opens it in a vertical split
M.NewVSplit = function()
	local current_dir = vim.fn.getcwd()
	vim.ui.input({ prompt = "Enter file path: " }, function(input)
		if input and input ~= "" then
			local filepath = vim.fs.joinpath(current_dir, input)
			if vim.fn.filereadable(filepath) == 1 then
				vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
			else
				vim.notify("File does not exist: " .. filepath, vim.log.levels.ERROR)
			end
		else
			vim.notify("No file provided.", vim.log.levels.WARN)
		end
	end)
end

return M
