-- plugin/sessions.lua
-- Per-project sessions keyed by project root (git / Cargo / go.mod / ...).
--
--   :SessionSave    save the session for the current project   <leader>Ss
--   :SessionLoad    load this project's session                <leader>Sl
--   :SessionPick    choose from every saved session            <leader>Sp
--   :SessionDelete  delete this project's session
--   :ProjectRoot    :cd to the project root
--
-- On exit a session is re-saved only if one already exists for the project, so
-- nothing is written until you have run :SessionSave once there.

local sessions_dir = vim.fn.stdpath "state" .. "/sessions"
local markers = { ".git", "Cargo.toml", "go.mod", "pyproject.toml", "package.json", "CMakeLists.txt", "Makefile" }

local function project_root()
  return vim.fs.root(0, markers) or vim.fn.getcwd()
end

local function session_file(root)
  return sessions_dir .. "/" .. (root:gsub("[/\\:]", "%%")) .. ".vim"
end

local function has_real_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then
      return true
    end
  end
  return false
end

local function with_session_options(fn)
  local saved = vim.o.sessionoptions
  vim.o.sessionoptions = "buffers,curdir,tabpages,winsize"
  local ok, err = pcall(fn)
  vim.o.sessionoptions = saved
  if not ok then
    vim.notify("Session error: " .. tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

local function save(quiet)
  if not has_real_buffers() then
    if not quiet then
      vim.notify("Nothing to save: no file buffers open", vim.log.levels.WARN)
    end
    return
  end
  local root = project_root()
  vim.fn.mkdir(sessions_dir, "p")
  local file = session_file(root)
  if with_session_options(function()
    vim.cmd("mksession! " .. vim.fn.fnameescape(file))
  end) and not quiet then
    vim.notify("Session saved for " .. root, vim.log.levels.INFO)
  end
end

local function load(file)
  if not file or not vim.uv.fs_stat(file) then
    vim.notify("No saved session for this project", vim.log.levels.WARN)
    return
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].modified then
      vim.notify("Unsaved changes: save or discard them before loading a session", vim.log.levels.ERROR)
      return
    end
  end
  with_session_options(function()
    vim.cmd("silent! source " .. vim.fn.fnameescape(file))
  end)
end

vim.api.nvim_create_user_command("SessionSave", function()
  save(false)
end, { desc = "Save session for this project" })

vim.api.nvim_create_user_command("SessionLoad", function()
  load(session_file(project_root()))
end, { desc = "Load session for this project" })

vim.api.nvim_create_user_command("SessionDelete", function()
  local file = session_file(project_root())
  if vim.uv.fs_stat(file) then
    vim.uv.fs_unlink(file)
    vim.notify("Session deleted", vim.log.levels.INFO)
  else
    vim.notify("No session to delete", vim.log.levels.WARN)
  end
end, { desc = "Delete this project's session" })

vim.api.nvim_create_user_command("SessionPick", function()
  local files = vim.fn.glob(sessions_dir .. "/*.vim", false, true)
  if #files == 0 then
    vim.notify("No saved sessions", vim.log.levels.WARN)
    return
  end
  vim.ui.select(files, {
    prompt = "Load session",
    format_item = function(f)
      return (vim.fn.fnamemodify(f, ":t:r"):gsub("%%", "/"))
    end,
  }, function(choice)
    if choice then
      load(choice)
    end
  end)
end, { desc = "Pick a saved session" })

vim.api.nvim_create_user_command("ProjectRoot", function()
  local root = project_root()
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.notify("cd " .. root, vim.log.levels.INFO)
end, { desc = "cd to the project root" })

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("SessionAutosave", { clear = true }),
  callback = function()
    if vim.uv.fs_stat(session_file(project_root())) then
      save(true)
    end
  end,
})

vim.keymap.set("n", "<leader>Ss", "<cmd>SessionSave<CR>", { desc = "Session: save" })
vim.keymap.set("n", "<leader>Sl", "<cmd>SessionLoad<CR>", { desc = "Session: load" })
vim.keymap.set("n", "<leader>Sp", "<cmd>SessionPick<CR>", { desc = "Session: pick" })
