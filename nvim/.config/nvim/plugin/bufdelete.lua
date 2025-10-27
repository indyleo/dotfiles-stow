-- bufdelete.lua
-- Minimal buffer delete plugin (Neovim 0.11.4 compatible)
-- Drop this file in: ~/.config/nvim/plugin/bufdelete.lua

local function is_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
end

local function get_alternate_buffer(current)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if is_valid(b) and b ~= current then
      return b
    end
  end
  return nil
end

local function delete_buffer(buf, force)
  buf = buf or vim.api.nvim_get_current_buf()
  if not is_valid(buf) then
    return
  end

  local alt = get_alternate_buffer(buf)
  local wins = vim.fn.win_findbuf(buf)

  for _, win in ipairs(wins) do
    if alt then
      vim.api.nvim_win_set_buf(win, alt)
    else
      vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
    end
  end

  local cmd = force and "bdelete!" or "bdelete"
  vim.cmd(cmd .. " " .. buf)
end

local function wipeout_buffer(buf, force)
  buf = buf or vim.api.nvim_get_current_buf()
  if not is_valid(buf) then
    return
  end

  local alt = get_alternate_buffer(buf)
  local wins = vim.fn.win_findbuf(buf)

  for _, win in ipairs(wins) do
    if alt then
      vim.api.nvim_win_set_buf(win, alt)
    else
      vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
    end
  end

  local cmd = force and "bwipeout!" or "bwipeout"
  vim.cmd(cmd .. " " .. buf)
end

vim.api.nvim_create_user_command("Bdelete", function(opts)
  delete_buffer(nil, opts.bang)
end, { bang = true, desc = "Delete buffer without closing windows" })

vim.api.nvim_create_user_command("Bwipeout", function(opts)
  wipeout_buffer(nil, opts.bang)
end, { bang = true, desc = "Wipeout buffer without closing windows" })
