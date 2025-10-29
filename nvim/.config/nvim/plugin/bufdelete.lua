-- bufdelete.lua
-- Safe buffer deletion without closing windows.

if vim.g.loaded_bufdelete_plugin then
  return
end
vim.g.loaded_bufdelete_plugin = true

local api, fn = vim.api, vim.fn

local function is_valid(buf)
  return buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
end

local function get_alternate_buffer(current)
  for _, b in ipairs(api.nvim_list_bufs()) do
    if is_valid(b) and b ~= current then
      return b
    end
  end
  return nil
end

local function switch_windows(buf, alt)
  for _, win in ipairs(fn.win_findbuf(buf)) do
    if alt then
      api.nvim_win_set_buf(win, alt)
    else
      api.nvim_win_set_buf(win, api.nvim_create_buf(true, false))
    end
  end
end

local function delete_buffer(force)
  local buf = api.nvim_get_current_buf()
  if not is_valid(buf) then
    return false
  end
  if vim.bo[buf].modified and not force then
    vim.notify("Buffer has unsaved changes. Use :Bdelete! to force.", vim.log.levels.WARN)
    return false
  end

  local alt = get_alternate_buffer(buf)
  switch_windows(buf, alt)
  api.nvim_buf_delete(buf, { force = force })
  return true
end

local function wipeout_buffer(force)
  local buf = api.nvim_get_current_buf()
  if not is_valid(buf) then
    return false
  end

  local alt = get_alternate_buffer(buf)
  switch_windows(buf, alt)
  api.nvim_buf_delete(buf, { force = force, unload = true })
  return true
end

api.nvim_create_user_command("Bdelete", function(opts)
  delete_buffer(opts.bang)
end, { bang = true, desc = "Delete buffer without closing windows" })

api.nvim_create_user_command("Bwipeout", function(opts)
  wipeout_buffer(opts.bang)
end, { bang = true, desc = "Wipeout buffer without closing windows" })

vim.keymap.set("n", "<leader>bd", "<cmd>Bdelete<CR>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bw", "<cmd>Bwipeout<CR>", { desc = "Wipeout buffer" })

return { delete = delete_buffer, wipeout = wipeout_buffer }
