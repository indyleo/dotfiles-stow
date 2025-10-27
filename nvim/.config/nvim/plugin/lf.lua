local function open_lf_in_float()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
  })

  local cwd = vim.fn.getcwd()
  local last_dir_file = vim.fn.expand "~/.cache/lf_last_dir"

  local function set_cwd(new_dir)
    if new_dir and vim.fn.isdirectory(new_dir) == 1 then
      local current = vim.fn.getcwd()
      if current ~= new_dir then
        vim.cmd("cd " .. vim.fn.fnameescape(new_dir))
        vim.api.nvim_echo({ { "📁 cwd changed: " .. new_dir, "Directory" } }, false, {})
      end
    end
  end

  vim.fn.termopen({ "lf", "-last-dir-path", last_dir_file }, {
    cwd = cwd,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line and line ~= "" and vim.fn.filereadable(vim.trim(line)) == 1 then
          vim.schedule(function()
            local file = vim.fn.fnameescape(vim.trim(line))
            local file_dir = vim.fn.fnamemodify(file, ":p:h")

            -- Set cwd only if it changed
            set_cwd(file_dir)

            -- Open file in main window
            local main_win = vim.fn.win_getid(vim.fn.winnr "#")
            if vim.api.nvim_win_is_valid(main_win) then
              vim.api.nvim_set_current_win(main_win)
            end
            vim.cmd("edit " .. file)

            -- Close the float
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end)
        end
      end
    end,

    on_exit = function()
      vim.schedule(function()
        -- Optional: update cwd to LF's last browsing directory if changed
        local f = io.open(last_dir_file, "r")
        if f then
          local last_dir = f:read "*l"
          f:close()
          set_cwd(last_dir)
        end
      end)
    end,
  })

  vim.cmd "startinsert"
end

vim.api.nvim_create_user_command("Lf", open_lf_in_float, { bang = true, desc = "Open lf in a floating window" })
