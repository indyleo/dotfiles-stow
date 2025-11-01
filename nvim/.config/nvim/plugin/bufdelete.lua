-- bufdelete.lua
-- Safe buffer deletion without closing windows.

if vim.g.loaded_bufdelete_plugin then
  return
end
vim.g.loaded_bufdelete_plugin = true

local api, fn = vim.api, vim.fn

-- Check if buffer is valid and listed
local function is_valid(buf)
  return buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
end

-- Get alternate buffer, preferring most recently used
local function get_alternate_buffer(current)
  -- Try alternate buffer first (# register)
  local alt = fn.bufnr "#"
  if is_valid(alt) and alt ~= current then
    return alt
  end

  -- Find next valid buffer in list
  local bufs = api.nvim_list_bufs()
  for _, b in ipairs(bufs) do
    if is_valid(b) and b ~= current then
      return b
    end
  end

  return nil
end

-- Switch all windows showing buffer to alternate
local function switch_windows(buf, alt)
  local wins = fn.win_findbuf(buf)

  for _, win in ipairs(wins) do
    -- Skip if not a normal window
    local wintype = fn.win_gettype(win)
    if wintype == "" then
      if alt then
        api.nvim_win_set_buf(win, alt)
      else
        -- Create new empty buffer
        local new_buf = api.nvim_create_buf(true, false)
        api.nvim_win_set_buf(win, new_buf)
      end
    end
  end
end

-- Check for unsaved changes
local function has_unsaved_changes(buf)
  return vim.bo[buf].modified and not vim.bo[buf].buftype or vim.bo[buf].buftype == ""
end

-- Delete buffer safely
local function delete_buffer(force)
  local buf = api.nvim_get_current_buf()

  if not is_valid(buf) then
    vim.notify("Buffer is not valid or not listed", vim.log.levels.WARN)
    return false
  end

  if has_unsaved_changes(buf) and not force then
    vim.notify("Buffer has unsaved changes. Use :Bdelete! to force.", vim.log.levels.WARN)
    return false
  end

  local alt = get_alternate_buffer(buf)
  switch_windows(buf, alt)

  local ok, err = pcall(api.nvim_buf_delete, buf, { force = force })
  if not ok then
    vim.notify("Failed to delete buffer: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Wipeout buffer safely
local function wipeout_buffer(force)
  local buf = api.nvim_get_current_buf()

  if not is_valid(buf) then
    vim.notify("Buffer is not valid or not listed", vim.log.levels.WARN)
    return false
  end

  if has_unsaved_changes(buf) and not force then
    vim.notify("Buffer has unsaved changes. Use :Bwipeout! to force.", vim.log.levels.WARN)
    return false
  end

  local alt = get_alternate_buffer(buf)
  switch_windows(buf, alt)

  local ok, err = pcall(api.nvim_buf_delete, buf, { force = force, unload = true })
  if not ok then
    vim.notify("Failed to wipeout buffer: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Delete buffer by number or name
local function delete_buffer_by_target(target, force)
  local buf

  if type(target) == "number" then
    buf = target
  elseif type(target) == "string" then
    buf = fn.bufnr(target)
  else
    buf = api.nvim_get_current_buf()
  end

  if buf == -1 or not api.nvim_buf_is_valid(buf) then
    vim.notify("Invalid buffer: " .. tostring(target), vim.log.levels.ERROR)
    return false
  end

  local alt = get_alternate_buffer(buf)
  switch_windows(buf, alt)

  local ok, err = pcall(api.nvim_buf_delete, buf, { force = force })
  if not ok then
    vim.notify("Failed to delete buffer: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Create user commands
api.nvim_create_user_command("Bdelete", function(opts)
  if opts.args ~= "" then
    delete_buffer_by_target(opts.args, opts.bang)
  else
    delete_buffer(opts.bang)
  end
end, {
  bang = true,
  nargs = "?",
  complete = "buffer",
  desc = "Delete buffer without closing windows",
})

api.nvim_create_user_command("Bwipeout", function(opts)
  wipeout_buffer(opts.bang)
end, {
  bang = true,
  desc = "Wipeout buffer without closing windows",
})

-- Export functions
return {
  delete = delete_buffer,
  wipeout = wipeout_buffer,
  delete_by_target = delete_buffer_by_target,
}
