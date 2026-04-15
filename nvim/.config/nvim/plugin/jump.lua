-- jump.lua
-- Minimal flash.nvim-style jump plugin — drop into ~/.config/nvim/plugin/
-- Gruvbox-themed highlight groups, no external dependencies.
--
-- Commands:
--   :FlashJump       — open jump prompt (any pattern)
--   :FlashJumpWord   — jump to word starts only
--
-- Suggested keymaps (add to your init.lua / keymaps file):
--   vim.keymap.set({ "n", "x", "o" }, "s", "<cmd>FlashJump<cr>",     { desc = "Flash Jump" })
--   vim.keymap.set({ "n", "x", "o" }, "S", "<cmd>FlashJumpWord<cr>", { desc = "Flash Jump (word starts)" })

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

-- ── State ────────────────────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace "flash_jump"
local labels = "sfnjklhodweimbuyvrgtaqpcxz"

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, ns, 0, -1)
end

-- Collect all visible matches of `pattern` in the current window.
-- Returns list of { lnum, col } (0-indexed).
local function collect_matches(pattern, word_start)
  local bufnr = vim.api.nvim_get_current_buf()
  local top = vim.fn.line "w0" - 1
  local bot = vim.fn.line "w$" - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, top, bot + 1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_lnum = cursor[1] - 1
  local cur_col = cursor[2]

  local matches = {}
  local search_pat = word_start and ("\\<" .. vim.fn.escape(pattern, "\\")) or vim.fn.escape(pattern, "\\")

  for rel, line in ipairs(lines) do
    local lnum = top + rel - 1
    local col = 0
    while true do
      local s, e = vim.regex(search_pat):match_str(line:sub(col + 1))
      if not s then
        break
      end
      local abs_col = col + s
      -- skip the exact cursor position for cleanliness
      if not (lnum == cur_lnum and abs_col == cur_col) then
        matches[#matches + 1] = { lnum = lnum, col = abs_col }
      end
      col = col + s + math.max(e - s, 1)
      if col >= #line then
        break
      end
    end
  end

  -- sort by distance to cursor (closest first)
  table.sort(matches, function(a, b)
    local da = math.abs(a.lnum - cur_lnum) * 1000 + math.abs(a.col - cur_col)
    local db = math.abs(b.lnum - cur_lnum) * 1000 + math.abs(b.col - cur_col)
    return da < db
  end)

  return matches
end

-- Apply extmarks: dim backdrop, highlight matches, overlay labels.
local function apply_marks(bufnr, matches, pattern_len)
  clear(bufnr)
  local top = vim.fn.line "w0" - 1
  local bot = vim.fn.line "w$"
  local lines = vim.api.nvim_buf_get_lines(bufnr, top, bot, false)

  -- backdrop: dim entire visible area
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

  -- highlight matches and overlay labels
  for i, m in ipairs(matches) do
    local label = labels:sub(i, i)
    if label == "" then
      break
    end -- ran out of labels

    -- highlight the matched text
    vim.api.nvim_buf_set_extmark(bufnr, ns, m.lnum, m.col, {
      end_col = m.col + pattern_len,
      hl_group = i == 1 and "FlashJumpCurrent" or "FlashJumpMatch",
      priority = 200,
    })

    -- overlay the label character
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
  local matches = {}

  -- tiny prompt in the cmdline
  local function redraw_prompt()
    vim.api.nvim_echo({ { "Prompt: ", "FlashJumpLabel" }, { pattern, "Normal" } }, false, {})
  end

  local function finish()
    clear(bufnr)
    vim.api.nvim_echo({ { "" } }, false, {})
  end

  redraw_prompt()

  while true do
    local ok, char = pcall(vim.fn.getcharstr)
    if not ok or char == "\27" then -- Escape
      finish()
      return
    end

    if char == "\r" then -- Enter — jump to first match
      if #matches > 0 then
        finish()
        vim.api.nvim_win_set_cursor(0, { matches[1].lnum + 1, matches[1].col })
        vim.cmd "normal! m'" -- push to jumplist
      else
        finish()
      end
      return
    end

    -- Backspace: remove last character
    if char == "\8" or char == "\127" or char == vim.api.nvim_replace_termcodes("<BS>", true, false, true) then
      if #pattern > 0 then
        pattern = pattern:sub(1, -2)
      end
    -- Delete: clear the whole pattern
    elseif char == vim.api.nvim_replace_termcodes("<Del>", true, false, true) then
      pattern = ""
    else
      -- Only treat char as a label pick when:
      --   1. we already have matches on screen, AND
      --   2. appending it to the pattern would produce zero new matches
      --      (meaning the user is done typing and is now selecting, not still typing)
      if #matches > 0 and #pattern > 0 then
        local would_match = #collect_matches(pattern .. char, word_start) > 0
        if not would_match then
          local idx = labels:find(char, 1, true)
          if idx and idx <= #matches then
            finish()
            local m = matches[idx]
            vim.cmd "normal! m'"
            vim.api.nvim_win_set_cursor(0, { m.lnum + 1, m.col })
            return
          end
        end
      end
      pattern = pattern .. char
    end

    if #pattern == 0 then
      clear(bufnr)
      redraw_prompt()
    else
      matches = collect_matches(pattern, word_start)
      apply_marks(bufnr, matches, #pattern)
      redraw_prompt()
      vim.cmd "redraw"

      -- auto-jump if only one match
      if #matches == 1 then
        finish()
        vim.cmd "normal! m'"
        vim.api.nvim_win_set_cursor(0, { matches[1].lnum + 1, matches[1].col })
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
