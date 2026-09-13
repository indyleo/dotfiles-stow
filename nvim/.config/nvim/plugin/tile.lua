-- plugin/tile.lua
-- Master/stack window tiling, ported from the wezterm master/stack
-- setup:
--
--   +-------------+----------------+
--   |             |    stack 1     |
--   |   master    +----------------+
--   |             |    stack 2     |
--   |             +----------------+
--   |             |    stack 3     |
--   +-------------+----------------+
--
-- Commands:
--   :TileSpawn       -- spawn/grow the next tile
--   :TileSwapMaster  -- swap focused stack window with master
--   :TileFocus       -- jump between master and first stack window
--   :TileEqualize    -- manually re-equalize the stack heights
--
-- Keymaps live in lua/keymaps.lua (see the "Master/stack tiling"
-- section), matching how :Lf, :MarksAdd, :JumpWord etc. are wired up
-- elsewhere in this config.
if vim.g.loaded_tile_plugin then
  return
end
vim.g.loaded_tile_plugin = true

local api = vim.api

------------------------------------------------------------
-- State
--
-- Keyed by tabpage handle -- Neovim has no per-tab "workspace" like
-- wezterm's mux, so each tabpage just gets its own independent
-- master/stack.
------------------------------------------------------------
local tile_state = {}

local function get_state(tabpage)
  tabpage = tabpage or api.nvim_get_current_tabpage()
  local state = tile_state[tabpage]

  if not state then
    state = { master = nil, stack = {} }
    tile_state[tabpage] = state
  end

  -- Prune dead windows.
  local live = {}
  for _, w in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
    live[w] = true
  end

  if state.master and not live[state.master] then
    state.master = nil
  end

  local stack = {}
  for _, w in ipairs(state.stack) do
    if live[w] and w ~= state.master then
      stack[#stack + 1] = w
    end
  end
  state.stack = stack

  return state
end

local function win_row_col(win)
  local pos = api.nvim_win_get_position(win) -- { row, col }, screen-relative
  return pos[1], pos[2]
end

-- If this tabpage hasn't been tiled by us yet (e.g. Neovim started with
-- a manual split layout already in place), adopt whatever's there:
-- left-most window becomes master, everything else becomes the stack.
local function register_existing_layout(tabpage)
  local state = get_state(tabpage)
  if state.master then
    return state
  end

  local wins = api.nvim_tabpage_list_wins(tabpage)
  if #wins == 0 then
    return state
  end

  table.sort(wins, function(a, b)
    local a_row, a_col = win_row_col(a)
    local b_row, b_col = win_row_col(b)
    if a_col == b_col then
      return a_row < b_row
    end
    return a_col < b_col
  end)

  state.master = wins[1]
  for i = 2, #wins do
    state.stack[#state.stack + 1] = wins[i]
  end

  return state
end

local function find_win(win)
  if win and api.nvim_win_is_valid(win) then
    return win
  end
  return nil
end

-- Resolve the bottom-most stack window from actual on-screen position,
-- not insertion order, so new splits always anchor off the true bottom
-- of the column instead of nesting deeper into one shrinking window.
local function bottom_stack_win(state)
  local infos = {}
  for _, w in ipairs(state.stack) do
    if api.nvim_win_is_valid(w) then
      infos[#infos + 1] = { win = w, row = win_row_col(w) }
    end
  end

  if #infos == 0 then
    return nil
  end

  table.sort(infos, function(a, b)
    return a.row < b.row
  end)

  return infos[#infos].win
end

local function equalize_stack(state)
  local wins = {}
  local total = 0

  for _, w in ipairs(state.stack) do
    if api.nvim_win_is_valid(w) then
      wins[#wins + 1] = w
      total = total + api.nvim_win_get_height(w)
    end
  end

  if #wins < 2 then
    return
  end

  local count = #wins
  local base = math.floor(total / count)
  local remainder = total - base * count -- give the leftover rows to the top few

  for i, w in ipairs(wins) do
    local h = base
    if i <= remainder then
      h = h + 1
    end
    api.nvim_win_set_height(w, h)
  end
end

------------------------------------------------------------
-- Actions
------------------------------------------------------------

-- Spawn the next tile. First call on a tabpage just claims the current
-- window as master; every call after that splits off the current
-- bottom of the stack and re-equalizes.
local function spawn_tile()
  local tabpage = api.nvim_get_current_tabpage()
  local state = register_existing_layout(tabpage)

  if not state.master then
    state.master = api.nvim_get_current_win()
    return
  end

  if #state.stack == 0 then
    -- "belowright" forces the split to the right regardless of 'splitright'.
    vim.cmd "belowright vsplit"
    state.stack[#state.stack + 1] = api.nvim_get_current_win()
    return
  end

  local anchor = bottom_stack_win(state)
  if not anchor then
    return
  end

  api.nvim_set_current_win(anchor)
  -- "belowright" forces the split downward regardless of 'splitbelow';
  -- the initial size doesn't matter since equalize_stack() below
  -- corrects every boundary afterward.
  vim.cmd "belowright split"
  state.stack[#state.stack + 1] = api.nvim_get_current_win()

  equalize_stack(state)
end

-- Swap the focused stack window with master.
--
-- Neovim has no direct equivalent of wezterm's PaneSelect
-- SwapWithActiveKeepFocus (which swaps two panes' positions in the mux
-- tree). Swapping the *buffers* shown in the two windows is the
-- simplest reliable stand-in -- the content moves between master and
-- stack slots, which is what actually matters here.
local function swap_master_stack()
  local tabpage = api.nvim_get_current_tabpage()
  local state = register_existing_layout(tabpage)
  if not state.master or #state.stack == 0 then
    return
  end

  local cur = api.nvim_get_current_win()
  local master, target = state.master, nil

  if cur == master then
    target = state.stack[1]
  else
    for _, w in ipairs(state.stack) do
      if w == cur then
        target = w
        break
      end
    end
    if not target then
      return -- current window isn't part of this tile at all
    end
  end

  if not (find_win(master) and find_win(target)) then
    return
  end

  local buf_master = api.nvim_win_get_buf(master)
  local buf_target = api.nvim_win_get_buf(target)
  api.nvim_win_set_buf(master, buf_target)
  api.nvim_win_set_buf(target, buf_master)
  api.nvim_set_current_win(target)
end

-- Master -> first stack window. Any stack window -> master.
local function focus_master_stack()
  local tabpage = api.nvim_get_current_tabpage()
  local state = register_existing_layout(tabpage)
  local master = find_win(state.master)
  if not master then
    return
  end

  if api.nvim_get_current_win() == master then
    local first_stack = find_win(state.stack[1])
    if first_stack then
      api.nvim_set_current_win(first_stack)
    end
  else
    api.nvim_set_current_win(master)
  end
end

------------------------------------------------------------
-- Auto-rebalance stack when a window closes
--
-- Neovim has a real WinClosed event (unlike wezterm, which has none
-- and has to poll pane counts instead). It still fires just before
-- the window is actually gone, so the rebalance is deferred one tick
-- to let the layout settle first.
------------------------------------------------------------
api.nvim_create_autocmd("WinClosed", {
  group = api.nvim_create_augroup("TileAutoRebalance", { clear = true }),
  callback = function()
    vim.schedule(function()
      for tabpage, state in pairs(tile_state) do
        if not api.nvim_tabpage_is_valid(tabpage) then
          tile_state[tabpage] = nil
          goto continue
        end

        local live = {}
        for _, w in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
          live[w] = true
        end

        if state.master and not live[state.master] then
          -- Master died; drop the cache and let the next tiling action
          -- re-derive master/stack from whatever layout remains.
          tile_state[tabpage] = nil
          goto continue
        end

        local new_stack = {}
        local changed = false
        for _, w in ipairs(state.stack) do
          if live[w] then
            new_stack[#new_stack + 1] = w
          else
            changed = true
          end
        end
        state.stack = new_stack

        if changed and #state.stack >= 2 then
          equalize_stack(state)
        end

        ::continue::
      end
    end)
  end,
})

------------------------------------------------------------
-- User Commands
------------------------------------------------------------
local mkcmd = api.nvim_create_user_command

mkcmd("TileSpawn", spawn_tile, { desc = "Master/stack: spawn/grow next tile" })
mkcmd("TileSwapMaster", swap_master_stack, { desc = "Master/stack: swap focused window with master" })
mkcmd("TileFocus", focus_master_stack, { desc = "Master/stack: focus master/stack" })
mkcmd("TileEqualize", function()
  local state = register_existing_layout(api.nvim_get_current_tabpage())
  equalize_stack(state)
end, { desc = "Master/stack: re-equalize stack heights" })
