-- jump.lua  (~/.config/nvim/plugin/jump.lua)
-- Lightweight flash.nvim-style jump plugin
-- Usage: press <leader>s (or remap below) to activate jump mode

local M = {}

-- ── config ────────────────────────────────────────────────────────────────────
local cfg = {
  -- highlight group used to dim the rest of the buffer
  dim_hl       = "JumpDim",
  -- highlight group for the jump labels
  label_hl     = "JumpLabel",
  -- highlight group for matched characters
  match_hl     = "JumpMatch",
  -- characters used as jump labels (in order of preference)
  labels       = "asdfghjklqwertyuiopzxcvbnmASDFGHJKLQWERTYUIOPZXCVBNM",
  -- only search visible lines (true) or whole buffer (false)
  visible_only = true,
  -- case sensitivity: "smart" | "ignore" | "exact"
  case         = "smart",
}

-- ── highlight setup ───────────────────────────────────────────────────────────
local function setup_hl()
  vim.api.nvim_set_hl(0, cfg.dim_hl,   { fg = "#555555", default = true })
  vim.api.nvim_set_hl(0, cfg.label_hl, { fg = "#ff007c", bold = true, default = true })
  vim.api.nvim_set_hl(0, cfg.match_hl, { fg = "#ffaf00", bold = true, default = true })
end

-- ── utilities ─────────────────────────────────────────────────────────────────
local ns = vim.api.nvim_create_namespace("jump_plugin")

local function clear_ns(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

local function visible_range(win)
  local top  = vim.fn.line("w0", win) - 1   -- 0-indexed
  local bot  = vim.fn.line("w$", win)        -- exclusive end (line count)
  return top, bot
end

local function buf_lines(buf, top, bot)
  return vim.api.nvim_buf_get_lines(buf, top, bot, false)
end

-- ── core jump logic ───────────────────────────────────────────────────────────
-- Returns a list of {lnum (0-indexed), col (byte), len} for every match of
-- `pattern` in the visible (or full) buffer.
local function find_matches(buf, win, pattern)
  local top, bot
  if cfg.visible_only then
    top, bot = visible_range(win)
  else
    top, bot = 0, vim.api.nvim_buf_line_count(buf)
  end

  local lines   = buf_lines(buf, top, bot)
  local matches = {}
  local flags   = (cfg.case == "exact") and "" or (cfg.case == "ignore") and "i" or ""

  for i, line in ipairs(lines) do
    local lnum   = top + i - 1
    local col    = 0
    while true do
      local s, e = line:find(pattern, col + 1, false)
      if not s then break end
      table.insert(matches, { lnum = lnum, col = s - 1, len = e - s + 1 })
      col = s  -- advance past start so we don't loop forever on zero-width
    end
  end
  return matches
end

-- Assign one label character per match (wraps if more matches than labels).
local function assign_labels(matches)
  local labeled = {}
  for i, m in ipairs(matches) do
    local ch = cfg.labels:sub(((i - 1) % #cfg.labels) + 1, ((i - 1) % #cfg.labels) + 1)
    labeled[ch] = m
    m.label     = ch
  end
  return labeled
end

-- Apply extmarks: dim whole buffer, highlight matches, overlay labels.
local function render(buf, matches)
  local line_count = vim.api.nvim_buf_line_count(buf)
  -- dim the whole buffer
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    end_row   = line_count,
    hl_group  = cfg.dim_hl,
    hl_eol    = true,
    priority  = 100,
  })

  for _, m in ipairs(matches) do
    -- highlight the matched text
    vim.api.nvim_buf_set_extmark(buf, ns, m.lnum, m.col, {
      end_col  = m.col + m.len,
      hl_group = cfg.match_hl,
      priority = 200,
    })
    -- overlay the label on the first character
    vim.api.nvim_buf_set_extmark(buf, ns, m.lnum, m.col, {
      virt_text         = { { m.label, cfg.label_hl } },
      virt_text_pos     = "overlay",
      priority          = 300,
    })
  end
end

-- ── main entry point ──────────────────────────────────────────────────────────
function M.jump()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  setup_hl()

  -- 1. Read the search pattern character-by-character until the user picks a
  --    label or presses <Esc>/<CR>.
  local typed   = ""
  local labeled = {}

  local function redraw_matches()
    clear_ns(buf)
    if #typed == 0 then return end

    -- Build a vim regex-safe pattern from the typed string
    local pat = vim.fn.escape(typed, "\\^$.*[]~")
    -- respect case setting
    if cfg.case == "smart" then
      pat = (typed == typed:lower()) and ("\\c" .. pat) or ("\\C" .. pat)
    elseif cfg.case == "ignore" then
      pat = "\\c" .. pat
    end

    local matches = find_matches(buf, win, pat)
    labeled       = assign_labels(matches)
    render(buf, matches)
    vim.cmd("redraw")
  end

  -- Show a prompt in the command line while in jump mode
  vim.api.nvim_echo({ { "jump> ", "ModeMsg" } }, false, {})

  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then break end  -- interrupted

    -- Escape or Ctrl-C → abort
    if ch == "\27" or ch == "\3" then
      break

    -- Backspace → remove last char from search
    elseif ch == "\8" or ch == "\127" then
      typed = typed:sub(1, -2)
      redraw_matches()

    -- Enter → if exactly one match, jump to it
    elseif ch == "\r" then
      if #vim.tbl_keys(labeled) == 1 then
        local m = vim.tbl_values(labeled)[1]
        vim.api.nvim_win_set_cursor(win, { m.lnum + 1, m.col })
      end
      break

    else
      -- Check if the typed char is a jump label
      if #typed > 0 and labeled[ch] then
        local m = labeled[ch]
        clear_ns(buf)
        vim.api.nvim_win_set_cursor(win, { m.lnum + 1, m.col })
        break
      else
        -- Otherwise it's part of the search pattern
        typed = typed .. ch
        redraw_matches()
      end
    end
  end

  clear_ns(buf)
  vim.cmd("redraw")
end

-- ── keymaps ───────────────────────────────────────────────────────────────────
vim.keymap.set({ "n", "x", "o" }, "<leader>s", M.jump, {
  desc   = "Jump: flash-style search",
  silent = true,
})

return M
