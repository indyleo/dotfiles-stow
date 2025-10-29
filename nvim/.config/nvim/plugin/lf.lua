-- Open lf file manager in a floating terminal.
if vim.g.loaded_lf_plugin then
  return
end
vim.g.loaded_lf_plugin = true

local api, fn, loop = vim.api, vim.fn, vim.loop

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  -- Resolve symlinks and remove redundant separators
  local resolved = loop.fs_realpath(path) or fn.fnamemodify(path, ":p")
  -- Remove trailing slash (except root)
  if resolved:sub(-1) == "/" and #resolved > 1 then
    resolved = resolved:sub(1, -2)
  end
  return resolved
end

local function open_lf_in_float()
  if fn.executable "lf" == 0 then
    vim.notify("lf not found in PATH", vim.log.levels.ERROR)
    return
  end

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
  })

  local cache_dir = fn.stdpath "cache"
  local last_dir_file = cache_dir .. "/lf_last_dir"

  local function set_cwd(new_dir)
    local normalized_new = normalize_path(new_dir)
    if not normalized_new or fn.isdirectory(normalized_new) == 0 then
      return
    end

    local normalized_current = normalize_path(fn.getcwd())

    if normalized_current ~= normalized_new then
      vim.cmd("cd " .. fn.fnameescape(normalized_new))
      api.nvim_echo({ { "📁 cwd changed: " .. normalized_new, "Directory" } }, false, {})
    end
  end

  local cwd = fn.getcwd()

  fn.termopen({ "lf", "-last-dir-path", last_dir_file }, {
    cwd = cwd,

    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        local trimmed = vim.trim(line)
        if trimmed ~= "" and fn.filereadable(trimmed) == 1 then
          vim.schedule(function()
            local file_dir = fn.fnamemodify(trimmed, ":p:h")
            set_cwd(file_dir)

            local main_win = fn.win_getid(fn.winnr "#")
            if api.nvim_win_is_valid(main_win) then
              api.nvim_set_current_win(main_win)
            end
            vim.cmd("edit " .. fn.fnameescape(trimmed))

            if api.nvim_win_is_valid(win) then
              api.nvim_win_close(win, true)
            end
          end)
        end
      end
    end,

    on_exit = function()
      vim.schedule(function()
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

api.nvim_create_user_command("Lf", open_lf_in_float, {
  bang = true,
  desc = "Open lf in floating window",
})

return { open = open_lf_in_float }
