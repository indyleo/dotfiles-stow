-- jump.lua
-- flash.nvim-style jump plugin — drop into ~/.config/nvim/plugin/
-- Gruvbox-themed highlight groups, no external dependencies.
--
-- How it works (matches flash.nvim's actual algorithm):
--   1. As you type, all visible matches are found and sorted by distance.
--   2. Each match is assigned a label from a pool of "safe" characters —
--      characters that do NOT appear immediately after any match in the
--      buffer. This means typing naturally never accidentally triggers a
--      label; only an actual label char fires the jump.
--   3. After every keystroke, the input is checked against the current
--      label set FIRST. If it matches a label → jump. Otherwise → the
--      char is appended to the search pattern and matches are refreshed.
--
-- Commands:
--   :Jump       — open jump prompt (any pattern)
--   :JumpWord   — jump to word starts only
--
-- Suggested keymaps:
--   vim.keymap.set({ "n", "x", "o" }, "s", "<cmd>Jump<cr>",     { desc = "Flash Jump" })
--   vim.keymap.set({ "n", "x", "o" }, "S", "<cmd>JumpWord<cr>", { desc = "Flash Jump (word starts)" })

-- ── Highlights (gruvbox palette) ────────────────────────────────────────────

vim.api.nvim_set_hl(0, "FlashJumpLabel", {
  fg = "#1d2021",
  bg = "#fabd2f",
  bold = true,
  ctermfg = 0,
  ctermbg = 11,
})
vim.api.nvim_set_hl(0, "FlashJumpMatch", {
  fg = "#fbf1c7",
  bg = "#458588",
  bold = false,
  ctermfg = 15,
  ctermbg = 4,
})
vim.api.nvim_set_hl(0, "FlashJumpBackdrop", {
  fg = "#665c54",
  ctermfg = 241,
})
vim.api.nvim_set_hl(0, "FlashJumpCurrent", {
  fg = "#1d2021",
  bg = "#fe8019",
  bold = true,
  ctermfg = 0,
  ctermbg = 208,
})

-- ── Config ───────────────────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace "flash_jump"

-- Candidate label characters, in priority order.
-- flash.nvim uses a similar set; keeping it lowercase-only reduces conflicts.
local LABEL_CHARS = "sfnjklhodweimbuyvrgtaqpcxz"

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, ns, 0, -1)
end

-- Collect all visible matches of `pattern` in the current window.
-- Returns list of { lnum, col, match_len, after_char } (0-indexed), sorted closest-first.
local function collect_matches(pattern, word_start)
  local bufnr = vim.api.nvim_get_current_buf()
  local top = vim.fn.line "w0" - 1
  local bot = vim.fn.line "w$" - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, top, bot + 1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_ln = cursor[1] - 1
  local cur_col = cursor[2]

  local search_pat = word_start and ("\\<" .. vim.fn.escape(pattern, "\\")) or vim.fn.escape(pattern, "\\")

  local matches = {}
  for rel, line in ipairs(lines) do
    local lnum = top + rel - 1
    local col = 0
    while true do
      local s, e = vim.regex(search_pat):match_str(line:sub(col + 1))
      if not s then
        break
      end
      local abs_col = col + s
      if not (lnum == cur_ln and abs_col == cur_col) then
        -- capture the char immediately after the match for safe-label computation
        local after_col = abs_col + (e - s)
        local after_char = line:sub(after_col + 1, after_col + 1):lower()
        matches[#matches + 1] = {
          lnum = lnum,
          col = abs_col,
          match_len = e - s,
          after_char = after_char,
        }
      end
      col = col + s + math.max(e - s, 1)
      if col >= #line then
        break
      end
    end
  end

  table.sort(matches, function(a, b)
    local da = math.abs(a.lnum - cur_ln) * 1000 + math.abs(a.col - cur_col)
    local db = math.abs(b.lnum - cur_ln) * 1000 + math.abs(b.col - cur_col)
    return da < db
  end)

  return matches
end

-- Assign safe labels to matches.
-- "Safe" means the label char does not appear immediately after any match,
-- so it can never be confused with the user continuing to type their pattern.
--
-- Returns:
--   labeled   — list of { match, label } in match order
--   label_map — { [label_char] = match } for O(1) lookup on keypress
local function assign_labels(matches)
  -- Build the unsafe set: every char that directly follows any match.
  local unsafe = {}
  for _, m in ipairs(matches) do
    if m.after_char ~= "" then
      unsafe[m.after_char] = true
    end
  end

  -- Pick safe labels in LABEL_CHARS priority order.
  local pool = {}
  for i = 1, #LABEL_CHARS do
    local c = LABEL_CHARS:sub(i, i)
    if not unsafe[c] then
      pool[#pool + 1] = c
    end
  end
  -- Edge-case fallback: if every candidate is unsafe, use the full set.
  if #pool == 0 then
    for i = 1, #LABEL_CHARS do
      pool[#pool + 1] = LABEL_CHARS:sub(i, i)
    end
  end

  local labeled = {}
  local label_map = {}
  for i, m in ipairs(matches) do
    local label = pool[i]
    if not label then
      break
    end -- more matches than labels available
    labeled[#labeled + 1] = { match = m, label = label }
    label_map[label] = m
  end

  return labeled, label_map
end

-- Render extmarks: backdrop → match highlights → label overlays.
local function apply_marks(bufnr, labeled)
  clear(bufnr)
  local top = vim.fn.line "w0" - 1
  local bot = vim.fn.line "w$"
  local lines = vim.api.nvim_buf_get_lines(bufnr, top, bot, false)

  -- Dim the whole visible area.
  for rel, line in ipairs(lines) do
    local lnum = top + rel - 1
    if #line > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
        end_col = #line,
        hl_group = "FlashJumpBackdrop",
        priority = 100,
        hl_mode = "combine",
      })
    end
  end

  -- Highlight each match and place its label overlay.
  for i, entry in ipairs(labeled) do
    local m = entry.match
    local label = entry.label

    vim.api.nvim_buf_set_extmark(bufnr, ns, m.lnum, m.col, {
      end_col = m.col + m.match_len,
      hl_group = i == 1 and "FlashJumpCurrent" or "FlashJumpMatch",
      priority = 200,
    })

    vim.api.nvim_buf_set_extmark(bufnr, ns, m.lnum, m.col, {
      virt_text = { { label, "FlashJumpLabel" } },
      virt_text_pos = "overlay",
      priority = 300,
    })
  end
end

-- ── Core jump logic ──────────────────────────────────────────────────────────

local function do_jump(opts)
  opts = opts or {}
  local word_start = opts.word_start or false
  local bufnr = vim.api.nvim_get_current_buf()
  local pattern = ""
  local label_map = {} -- rebuilt on every redraw

  local function redraw_prompt()
    vim.api.nvim_echo({
      { "Jump: ", "FlashJumpLabel" },
      { pattern, "Normal" },
    }, false, {})
  end

  local function finish()
    clear(bufnr)
    vim.api.nvim_echo({ { "" } }, false, {})
  end

  local function jump_to(m)
    finish()
    vim.cmd "normal! m'"
    vim.api.nvim_win_set_cursor(0, { m.lnum + 1, m.col })
  end

  -- Recompute matches, assign labels, redraw, return results.
  local function refresh()
    local matches = collect_matches(pattern, word_start)
    local labeled, lmap = assign_labels(matches)
    label_map = lmap
    apply_marks(bufnr, labeled)
    redraw_prompt()
    vim.cmd "redraw"
    return matches
  end

  redraw_prompt()

  while true do
    local ok, char = pcall(vim.fn.getcharstr)
    if not ok or char == "\27" then -- Escape → abort
      finish()
      return
    end

    -- Enter → jump to the closest match (index 1 after distance sort).
    if char == "\r" then
      if pattern ~= "" then
        local matches = collect_matches(pattern, word_start)
        if #matches > 0 then
          jump_to(matches[1])
        else
          finish()
        end
      else
        finish()
      end
      return
    end

    -- Backspace → trim one character off the pattern.
    if char == "\8" or char == "\127" or char == vim.api.nvim_replace_termcodes("<BS>", true, false, true) then
      if #pattern > 0 then
        pattern = pattern:sub(1, -2)
      end
      if #pattern == 0 then
        clear(bufnr)
        label_map = {}
        redraw_prompt()
      else
        refresh()
      end

    -- Delete → clear pattern entirely.
    elseif char == vim.api.nvim_replace_termcodes("<Del>", true, false, true) then
      pattern = ""
      label_map = {}
      clear(bufnr)
      redraw_prompt()
    else
      -- ── THE KEY DECISION ────────────────────────────────────────────────
      --
      -- Check label_map FIRST. Because safe labels are chosen to exclude
      -- any character that naturally follows a match in the buffer, this
      -- will only ever fire when the user deliberately picks a target —
      -- never as a side-effect of typing a word like "firefox".
      --
      local target = label_map[char:lower()]
      if target then
        jump_to(target)
        return
      end

      -- Not a label → extend the search pattern and refresh.
      pattern = pattern .. char
      local matches = refresh()

      -- Auto-jump when narrowed to exactly one result.
      if #matches == 1 then
        jump_to(matches[1])
        return
      end
    end
  end
end

-- ── User Commands ────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("Jump", function()
  do_jump { word_start = false }
end, { desc = "Flash Jump" })

vim.api.nvim_create_user_command("JumpWord", function()
  do_jump { word_start = true }
end, { desc = "Flash Jump (word starts only)" })
