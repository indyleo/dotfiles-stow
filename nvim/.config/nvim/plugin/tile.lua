-- plugin/tile.lua
--
-- Master / stack tiling for Neovim.
--
-- Layout:
--
--   +----------------------+----------------------+
--   |                      |       stack 1        |
--   |                      +----------------------+
--   |       MASTER         |       stack 2        |
--   |                      +----------------------+
--   |                      |       stack 3        |
--   +----------------------+----------------------+
--
-- :TileSpawn
--   Create master + stack 1 on first call.
--   Add another stack pane on subsequent calls.
--
-- :TileSwapMaster
--   Swap the current stack buffer with master.
--
-- :TileFocus
--   Master <-> first stack.
--
-- :TileEqualize
--   Equalize stack heights.

if vim.g.loaded_tile_plugin then
  return
end

vim.g.loaded_tile_plugin = true

local api = vim.api

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local MASTER_PERCENT = 60
local MAX_STACK = 12
local MIN_STACK_HEIGHT = 2

------------------------------------------------------------
-- State
------------------------------------------------------------

local tile_state = {}

local function valid_win(win)
  return win ~= nil and api.nvim_win_is_valid(win)
end

local function get_state(tab)
  if not tile_state[tab] then
    tile_state[tab] = {
      master = nil,
      stack = {},
    }
  end

  return tile_state[tab]
end

local function clean_state(tab)
  local state = get_state(tab)

  if state.master and not valid_win(state.master) then
    state.master = nil
  end

  local stack = {}

  for _, win in ipairs(state.stack) do
    if valid_win(win) then
      stack[#stack + 1] = win
    end
  end

  state.stack = stack

  return state
end

------------------------------------------------------------
-- Find stack windows by their actual position
------------------------------------------------------------

local function sort_stack(state)
  local stack = {}

  for _, win in ipairs(state.stack) do
    if valid_win(win) then
      stack[#stack + 1] = win
    end
  end

  table.sort(stack, function(a, b)
    local ap = api.nvim_win_get_position(a)
    local bp = api.nvim_win_get_position(b)

    if ap[1] ~= bp[1] then
      return ap[1] < bp[1]
    end

    return ap[2] < bp[2]
  end)

  state.stack = stack

  return stack
end

local function bottom_stack(state)
  local stack = sort_stack(state)

  return stack[#stack]
end

------------------------------------------------------------
-- Set master width
------------------------------------------------------------

local function set_master_width(state)
  if not valid_win(state.master) then
    return
  end

  if #state.stack == 0 then
    return
  end

  local stack_win = state.stack[1]

  if not valid_win(stack_win) then
    return
  end

  ----------------------------------------------------------
  -- The master and stack are siblings.
  --
  -- Their widths give us the actual usable width.
  ----------------------------------------------------------

  local master_width = api.nvim_win_get_width(state.master)
  local stack_width = api.nvim_win_get_width(stack_win)

  local total = master_width + stack_width + 1

  if total <= 0 then
    return
  end

  local desired = math.floor(total * MASTER_PERCENT / 100)

  ----------------------------------------------------------
  -- Keep enough room for the stack.
  ----------------------------------------------------------

  local max_master = total - 21

  desired = math.max(20, desired)
  desired = math.min(desired, max_master)

  pcall(api.nvim_win_set_width, state.master, desired)
end

------------------------------------------------------------
-- Equalize only the stack
------------------------------------------------------------

local function equalize_stack(state)
  local stack = sort_stack(state)

  local count = #stack

  if count == 0 then
    return
  end

  if count == 1 then
    set_master_width(state)
    return
  end

  ----------------------------------------------------------
  -- All stack windows should have the same total height.
  --
  -- Use the actual stack column height rather than summing
  -- arbitrary windows.
  ----------------------------------------------------------

  local first = stack[1]

  local total_height = api.nvim_win_get_height(first)

  if total_height <= 0 then
    return
  end

  ----------------------------------------------------------
  -- Find the usable height from all panes.
  ----------------------------------------------------------

  local sum = 0

  for _, win in ipairs(stack) do
    if valid_win(win) then
      sum = sum + api.nvim_win_get_height(win)
    end
  end

  if sum <= 0 then
    return
  end

  local base = math.floor(sum / count)
  local extra = sum % count

  if base < MIN_STACK_HEIGHT then
    return
  end

  ----------------------------------------------------------
  -- Resize top -> bottom.
  --
  -- Do NOT resize the final pane. Neovim will give it the
  -- remaining space.
  ----------------------------------------------------------

  for i = 1, count - 1 do
    local height = base

    if i <= extra then
      height = height + 1
    end

    pcall(api.nvim_win_set_height, stack[i], math.max(MIN_STACK_HEIGHT, height))
  end

  set_master_width(state)
end

------------------------------------------------------------
-- Create the first master/stack layout
------------------------------------------------------------

local function create_first_tile()
  local tab = api.nvim_get_current_tabpage()
  local state = get_state(tab)

  ----------------------------------------------------------
  -- The current window IS the master.
  ----------------------------------------------------------

  local master = api.nvim_get_current_win()

  if not valid_win(master) then
    return
  end

  state.master = master
  state.stack = {}

  ----------------------------------------------------------
  -- Save the current buffer.
  ----------------------------------------------------------

  local buf = api.nvim_win_get_buf(master)

  ----------------------------------------------------------
  -- IMPORTANT:
  --
  -- Explicitly use `vsplit`.
  --
  -- This creates:
  --
  --   +-------------+-------------+
  --   |             |             |
  --   |   MASTER    |    STACK    |
  --   |             |             |
  --   +-------------+-------------+
  --
  ----------------------------------------------------------

  api.nvim_set_current_win(master)

  vim.cmd "rightbelow vsplit"

  local stack_win = api.nvim_get_current_win()

  ----------------------------------------------------------
  -- Explicitly give the stack the SAME BUFFER.
  ----------------------------------------------------------

  api.nvim_win_set_buf(stack_win, buf)

  ----------------------------------------------------------
  -- Register it.
  ----------------------------------------------------------

  state.stack = {
    stack_win,
  }

  ----------------------------------------------------------
  -- Master should be wider.
  ----------------------------------------------------------

  set_master_width(state)

  ----------------------------------------------------------
  -- Leave focus on master.
  ----------------------------------------------------------

  api.nvim_set_current_win(master)
end

------------------------------------------------------------
-- Create another stack pane
------------------------------------------------------------

local function create_stack_tile()
  local tab = api.nvim_get_current_tabpage()
  local state = get_state(tab)

  local stack = sort_stack(state)

  if #stack == 0 then
    create_first_tile()
    return
  end

  if #stack >= MAX_STACK then
    vim.notify("Tile: maximum stack size reached (" .. MAX_STACK .. ")", vim.log.levels.WARN)
    return
  end

  ----------------------------------------------------------
  -- The bottom-most stack pane is our anchor.
  ----------------------------------------------------------

  local anchor = stack[#stack]

  if not valid_win(anchor) then
    return
  end

  ----------------------------------------------------------
  -- Save its buffer.
  --
  -- This makes the new pane show the same file instead of
  -- relying on Neovim's split inheritance.
  ----------------------------------------------------------

  local buf = api.nvim_win_get_buf(anchor)

  ----------------------------------------------------------
  -- IMPORTANT:
  --
  -- `split` = horizontal split.
  --
  -- Since anchor is already in the right-hand column,
  -- this creates another pane BELOW it in that column.
  ----------------------------------------------------------

  api.nvim_set_current_win(anchor)

  vim.cmd "belowright split"

  local new_win = api.nvim_get_current_win()

  ----------------------------------------------------------
  -- Explicitly copy the buffer.
  ----------------------------------------------------------

  api.nvim_win_set_buf(new_win, buf)

  ----------------------------------------------------------
  -- Register.
  ----------------------------------------------------------

  state.stack[#state.stack + 1] = new_win

  ----------------------------------------------------------
  -- Restore geometry.
  ----------------------------------------------------------

  equalize_stack(state)

  ----------------------------------------------------------
  -- Focus the new pane.
  ----------------------------------------------------------

  api.nvim_set_current_win(new_win)
end

------------------------------------------------------------
-- TileSpawn
------------------------------------------------------------

local function spawn_tile()
  local tab = api.nvim_get_current_tabpage()
  local state = clean_state(tab)

  ----------------------------------------------------------
  -- First-ever TileSpawn.
  ----------------------------------------------------------

  if not valid_win(state.master) then
    create_first_tile()
    return
  end

  ----------------------------------------------------------
  -- Master exists but no stack.
  ----------------------------------------------------------

  if #state.stack == 0 then
    create_first_tile()
    return
  end

  ----------------------------------------------------------
  -- Add another stack pane.
  ----------------------------------------------------------

  create_stack_tile()
end

------------------------------------------------------------
-- Swap master / stack
------------------------------------------------------------

local function swap_master_stack()
  local tab = api.nvim_get_current_tabpage()
  local state = clean_state(tab)

  if not valid_win(state.master) then
    return
  end

  local stack = sort_stack(state)

  if #stack == 0 then
    return
  end

  local current = api.nvim_get_current_win()
  local target = nil

  ----------------------------------------------------------
  -- Master -> stack 1.
  ----------------------------------------------------------

  if current == state.master then
    target = stack[1]
  else
    --------------------------------------------------------
    -- Stack pane -> that same stack pane.
    --------------------------------------------------------

    for _, win in ipairs(stack) do
      if win == current then
        target = win
        break
      end
    end
  end

  if not valid_win(target) then
    return
  end

  ----------------------------------------------------------
  -- Save buffers.
  ----------------------------------------------------------

  local master_buf = api.nvim_win_get_buf(state.master)
  local target_buf = api.nvim_win_get_buf(target)

  ----------------------------------------------------------
  -- Save views.
  ----------------------------------------------------------

  local master_view
  local target_view

  api.nvim_win_call(state.master, function()
    master_view = vim.fn.winsaveview()
  end)

  api.nvim_win_call(target, function()
    target_view = vim.fn.winsaveview()
  end)

  ----------------------------------------------------------
  -- Swap buffers.
  ----------------------------------------------------------

  api.nvim_win_set_buf(state.master, target_buf)
  api.nvim_win_set_buf(target, master_buf)

  ----------------------------------------------------------
  -- Restore views.
  ----------------------------------------------------------

  if target_view then
    api.nvim_win_call(state.master, function()
      vim.fn.winrestview(target_view)
    end)
  end

  if master_view then
    api.nvim_win_call(target, function()
      vim.fn.winrestview(master_view)
    end)
  end

  ----------------------------------------------------------
  -- Keep focus on the swapped stack pane.
  ----------------------------------------------------------

  api.nvim_set_current_win(target)
end

------------------------------------------------------------
-- TileFocus
------------------------------------------------------------

local function focus_tile()
  local tab = api.nvim_get_current_tabpage()
  local state = clean_state(tab)

  if not valid_win(state.master) then
    return
  end

  local current = api.nvim_get_current_win()

  ----------------------------------------------------------
  -- Master -> first stack.
  ----------------------------------------------------------

  if current == state.master then
    local stack = sort_stack(state)

    if valid_win(stack[1]) then
      api.nvim_set_current_win(stack[1])
    end

    return
  end

  ----------------------------------------------------------
  -- Anything else -> master.
  ----------------------------------------------------------

  api.nvim_set_current_win(state.master)
end

------------------------------------------------------------
-- Equalize command
------------------------------------------------------------

local function equalize_tile()
  local tab = api.nvim_get_current_tabpage()
  local state = clean_state(tab)

  equalize_stack(state)
end

------------------------------------------------------------
-- Automatic cleanup
------------------------------------------------------------

local function rebalance_all()
  for tab, state in pairs(tile_state) do
    if not api.nvim_tabpage_is_valid(tab) then
      tile_state[tab] = nil
      goto continue
    end

    --------------------------------------------------------
    -- Check whether master still exists.
    --------------------------------------------------------

    if state.master and not valid_win(state.master) then
      tile_state[tab] = nil
      goto continue
    end

    --------------------------------------------------------
    -- Remove closed stack windows.
    --------------------------------------------------------

    local stack = {}

    for _, win in ipairs(state.stack) do
      if valid_win(win) and win ~= state.master then
        stack[#stack + 1] = win
      end
    end

    state.stack = stack

    --------------------------------------------------------
    -- Rebalance.
    --------------------------------------------------------

    if #state.stack > 0 then
      equalize_stack(state)
    end

    ::continue::
  end
end

------------------------------------------------------------
-- Autocommands
------------------------------------------------------------

local augroup = api.nvim_create_augroup("TileAutoRebalance", { clear = true })

api.nvim_create_autocmd("WinClosed", {
  group = augroup,

  callback = function()
    vim.schedule(function()
      rebalance_all()
    end)
  end,
})

api.nvim_create_autocmd("VimResized", {
  group = augroup,

  callback = function()
    vim.schedule(function()
      rebalance_all()
    end)
  end,
})

------------------------------------------------------------
-- Commands
------------------------------------------------------------

api.nvim_create_user_command("TileSpawn", spawn_tile, {
  desc = "Master/stack: spawn next tile",
})

api.nvim_create_user_command("TileSwapMaster", swap_master_stack, {
  desc = "Master/stack: swap focused window with master",
})

api.nvim_create_user_command("TileFocus", focus_tile, {
  desc = "Master/stack: focus master/stack",
})

api.nvim_create_user_command("TileEqualize", equalize_tile, {
  desc = "Master/stack: equalize stack heights",
})
