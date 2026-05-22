-- plugin/lf.lua
-- Open lf file manager in a floating terminal.
if vim.g.loaded_lf_plugin then return end
vim.g.loaded_lf_plugin = true

local api, fn = vim.api, vim.fn
-- vim.uv replaces the deprecated vim.loop (Neovim 0.10+)
local uv = vim.uv or vim.loop

local function normalize_path(path)
  if not path or path == "" then return nil end
  local resolved = uv.fs_realpath(path) or fn.fnamemodify(path, ":p")
  if resolved:sub(-1) == "/" and #resolved > 1 then
    resolved = resolved:sub(1, -2)
  end
  return resolved
end

local function open_lf_in_float(opts)
  opts = opts or {}

  if fn.executable "lf" == 0 then
    vim.notify("lf not found in PATH", vim.log.levels.ERROR)
    return
  end

  local width  = opts.width  or math.floor(vim.o.columns * 0.9)
  local height = opts.height or math.floor(vim.o.lines   * 0.9)
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)

  local buf = api.nvim_create_buf(false, true)

  -- Use the non-deprecated API (nvim_set_option_value) for buffer options
  api.nvim_set_option_value("filetype",   "lf",   { buf = buf })
  api.nvim_set_option_value("bufhidden",  "wipe", { buf = buf })

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    border   = "rounded",
    style    = "minimal",
  })

  -- Use nvim_set_option_value for window options too
  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  local cache_dir      = fn.stdpath "cache"
  local last_dir_file  = cache_dir .. "/lf_last_dir"
  local selection_file = cache_dir .. "/lf_selection"

  local function set_cwd(new_dir)
    local normalized_new = normalize_path(new_dir)
    if not normalized_new or fn.isdirectory(normalized_new) == 0 then return end
    local normalized_current = normalize_path(fn.getcwd())
    if normalized_current ~= normalized_new then
      vim.cmd("cd " .. fn.fnameescape(normalized_new))
      api.nvim_echo({ { "📁 cwd: " .. normalized_new, "Directory" } }, false, {})
    end
  end

  local function open_file(file_path)
    local file_dir  = fn.fnamemodify(file_path, ":p:h")
    set_cwd(file_dir)
    local prev_win = fn.win_getid(fn.winnr "#")
    if api.nvim_win_is_valid(prev_win) and prev_win ~= win then
      api.nvim_set_current_win(prev_win)
    else
      if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    end
    vim.cmd("edit " .. fn.fnameescape(file_path))
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  local cwd    = opts.start_dir or fn.getcwd()
  local job_id = fn.termopen({
    "lf",
    "-last-dir-path=" .. last_dir_file,
    "-selection-path=" .. selection_file,
  }, {
    cwd     = cwd,
    on_exit = function(_, _)
      vim.schedule(function()
        local f = io.open(last_dir_file, "r")
        if f then
          local last_dir = f:read "*l"
          f:close()
          if last_dir and last_dir ~= "" then set_cwd(last_dir) end
          os.remove(last_dir_file)
        end

        local sel_f = io.open(selection_file, "r")
        if sel_f then
          local files = {}
          for line in sel_f:lines() do
            local trimmed = vim.trim(line)
            if trimmed ~= "" and fn.filereadable(trimmed) == 1 then
              table.insert(files, trimmed)
            end
          end
          sel_f:close()
          os.remove(selection_file)
          if #files > 0 then
            open_file(files[1])
            if #files > 1 then
              for i = 2, #files do
                vim.cmd("argadd " .. fn.fnameescape(files[i]))
              end
              vim.notify(string.format("Added %d files to arglist", #files - 1), vim.log.levels.INFO)
            end
          end
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start lf", vim.log.levels.ERROR)
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    return
  end

  local km = { nowait = true, silent = true, noremap = true }
  api.nvim_buf_set_keymap(buf, "t", "<Esc>",  [[<C-\><C-n>:close<CR>]], km)
  api.nvim_buf_set_keymap(buf, "t", "<C-q>",  [[<C-\><C-n>:close<CR>]], km)

  vim.cmd "startinsert"
end

api.nvim_create_user_command("Lf", function(cmd_opts)
  open_lf_in_float { start_dir = cmd_opts.args ~= "" and cmd_opts.args or nil }
end, {
  nargs    = "?",
  complete = "dir",
  desc     = "Open lf in floating window (optional: specify directory)",
})

local function setup(user_opts)
  user_opts = user_opts or {}
  if user_opts.keymap then
    vim.keymap.set("n", user_opts.keymap, open_lf_in_float, { desc = "Open lf" })
  end
end

return { open = open_lf_in_float, setup = setup }
