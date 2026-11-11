-- lf.lua
if vim.g.loaded_lf_plugin then
  return
end
vim.g.loaded_lf_plugin = true

local api, fn = vim.api, vim.fn
local uv = vim.uv or vim.loop

local lf_win = nil
local lf_buf = nil
local lf_job = nil

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  local resolved = uv.fs_realpath(path) or fn.fnamemodify(path, ":p")
  if resolved:sub(-1) == "/" and #resolved > 1 then
    resolved = resolved:sub(1, -2)
  end
  return resolved
end

local function get_float_dimensions()
  -- Keep the float inside Neovim's usable editor area, including on small
  -- terminals where a fixed percentage can otherwise exceed the screen.
  local max_width = math.max(1, vim.o.columns - 2)
  local max_height = math.max(1, vim.o.lines - vim.o.cmdheight - 2)
  local width = math.min(max_width, math.max(1, math.floor(vim.o.columns * 0.9)))
  local height = math.min(max_height, math.max(1, math.floor(max_height * 0.9)))

  return {
    width = width,
    height = height,
    row = math.max(0, math.floor((max_height - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  }
end

local function close_lf(stop_job)
  local win, job = lf_win, lf_job

  -- Clear shared state first so WinClosed/BufWipeout callbacks cannot act on
  -- a newly opened lf instance.
  lf_win, lf_buf, lf_job = nil, nil, nil

  if stop_job and job and job > 0 then
    pcall(fn.jobstop, job)
  end

  if win and api.nvim_win_is_valid(win) then
    pcall(api.nvim_win_close, win, true)
  end
end

local function resize_lf()
  if not lf_win or not api.nvim_win_is_valid(lf_win) then
    return
  end

  local size = get_float_dimensions()
  pcall(api.nvim_win_set_config, lf_win, {
    relative = "editor",
    width = size.width,
    height = size.height,
    row = size.row,
    col = size.col,
  })
end

local function open_lf_in_float(opts)
  opts = opts or {}

  if fn.executable("lf") == 0 then
    vim.notify("lf not found in PATH", vim.log.levels.ERROR)
    return
  end

  -- Reuse an already-open instance instead of creating an untracked float.
  if lf_win and api.nvim_win_is_valid(lf_win) then
    api.nvim_set_current_win(lf_win)
    return
  end

  local start_dir = normalize_path(opts.start_dir or fn.getcwd())
  if not start_dir or fn.isdirectory(start_dir) == 0 then
    vim.notify("Invalid lf starting directory", vim.log.levels.ERROR)
    return
  end

  local size = get_float_dimensions()
  local origin_win = api.nvim_get_current_win()
  local buf = api.nvim_create_buf(false, true)
  lf_buf = buf

  api.nvim_set_option_value("filetype", "lf", { buf = buf })
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  api.nvim_set_option_value("swapfile", false, { buf = buf })

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = size.width,
    height = size.height,
    row = size.row,
    col = size.col,
    border = "rounded",
    style = "minimal",
  })
  lf_win = win

  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  local cache_dir = fn.stdpath("cache")
  fn.mkdir(cache_dir, "p")

  local last_dir_file = cache_dir .. "/lf_last_dir"
  local selection_file = cache_dir .. "/lf_selection"

  -- A previous crash must not make this launch consume stale selections.
  os.remove(last_dir_file)
  os.remove(selection_file)

  local function set_cwd(new_dir)
    local normalized_new = normalize_path(new_dir)
    if not normalized_new or fn.isdirectory(normalized_new) == 0 then
      return
    end

    local normalized_current = normalize_path(fn.getcwd())
    if normalized_current ~= normalized_new then
      vim.cmd("cd " .. fn.fnameescape(normalized_new))
      api.nvim_echo({
        { " cwd: " .. normalized_new, "Directory" },
      }, false, {})
    end
  end

  local function open_file(file_path)
    if not file_path or file_path == "" then
      return
    end

    local absolute_path = fn.fnamemodify(file_path, ":p")
    if fn.filereadable(absolute_path) ~= 1 and fn.isdirectory(absolute_path) ~= 1 then
      vim.notify("Selected path does not exist: " .. absolute_path, vim.log.levels.WARN)
      return
    end

    local file_dir = fn.fnamemodify(absolute_path, ":h")
    set_cwd(file_dir)

    -- Return to the window from which :Lf was opened, not whichever window
    -- happens to be Neovim's alternate window.
    if origin_win and api.nvim_win_is_valid(origin_win) then
      api.nvim_set_current_win(origin_win)
    end

    vim.cmd("edit " .. fn.fnameescape(absolute_path))
  end

  local job_id = fn.termopen({
    "lf",
    "-last-dir-path=" .. last_dir_file,
    "-selection-path=" .. selection_file,
  }, {
    cwd = start_dir,

    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- Ignore callbacks belonging to an older lf instance.
        if lf_buf ~= buf then
          return
        end

        local last_dir
        local dir_file = io.open(last_dir_file, "r")
        if dir_file then
          last_dir = dir_file:read("*l")
          dir_file:close()
          os.remove(last_dir_file)
        end

        if last_dir and last_dir ~= "" then
          set_cwd(last_dir)
        end

        local selected = {}
        local sel_file = io.open(selection_file, "r")
        if sel_file then
          for line in sel_file:lines() do
            local trimmed = vim.trim(line)
            if trimmed ~= "" then
              -- Resolve relative selections while lf's final directory is
              -- still the current working directory.
              local absolute = fn.fnamemodify(trimmed, ":p")
              if fn.filereadable(absolute) == 1 then
                selected[#selected + 1] = absolute
              end
            end
          end
          sel_file:close()
          os.remove(selection_file)
        end

        local win = lf_win
        lf_win, lf_buf, lf_job = nil, nil, nil

        if win and api.nvim_win_is_valid(win) then
          pcall(api.nvim_win_close, win, true)
        end

        if #selected > 0 then
          open_file(selected[1])

          if #selected > 1 then
            for i = 2, #selected do
              vim.cmd("argadd " .. fn.fnameescape(selected[i]))
            end
            vim.notify(
              string.format("Added %d additional files to arglist", #selected - 1),
              vim.log.levels.INFO
            )
          end
        elseif origin_win and api.nvim_win_is_valid(origin_win) then
          api.nvim_set_current_win(origin_win)
        end

        if exit_code ~= 0 then
          vim.notify("lf exited with code " .. tostring(exit_code), vim.log.levels.WARN)
        end
      end)
    end,
  })

  if type(job_id) ~= "number" or job_id <= 0 then
    vim.notify("Failed to start lf", vim.log.levels.ERROR)
    close_lf(false)
    if origin_win and api.nvim_win_is_valid(origin_win) then
      api.nvim_set_current_win(origin_win)
    end
    return
  end

  lf_job = job_id

  local function map(lhs, desc)
    vim.keymap.set("t", lhs, function()
      close_lf(true)
      if origin_win and api.nvim_win_is_valid(origin_win) then
        api.nvim_set_current_win(origin_win)
      end
    end, {
      buffer = buf,
      silent = true,
      nowait = true,
      desc = desc,
    })
  end

  map("<Esc>", "Close lf")
  map("<C-q>", "Close lf")

  vim.cmd("startinsert")
end

api.nvim_create_autocmd("VimResized", {
  callback = resize_lf,
  desc = "Resize lf floating window",
})

api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
  callback = function()
    if lf_win and not api.nvim_win_is_valid(lf_win) then
      local job = lf_job
      lf_win, lf_buf, lf_job = nil, nil, nil
      if job and job > 0 then
        pcall(fn.jobstop, job)
      end
    elseif lf_buf and not api.nvim_buf_is_valid(lf_buf) then
      close_lf(true)
    end
  end,
  desc = "Clean up lf state when its window or buffer closes",
})

api.nvim_create_user_command("Lf", function(cmd_opts)
  open_lf_in_float {
    start_dir = cmd_opts.args ~= "" and cmd_opts.args or nil,
  }
end, {
  nargs = "?",
  complete = "dir",
  desc = "Open lf in floating window (optional: specify directory)",
})

local function setup(user_opts)
  user_opts = user_opts or {}

  if user_opts.keymap then
    vim.keymap.set("n", user_opts.keymap, open_lf_in_float, { desc = "Open lf" })
  end
end

return {
  open = open_lf_in_float,
  setup = setup,
}
