-- find_replace.lua
-- Floating-popup find & replace for the current buffer, modelled on grug-far.
-- Current file only (use LSP rename / quickfix for project-wide work).
-- Requires Neovim >= 0.10 and ripgrep. Search/replace syntax is ripgrep's
-- (Rust regex, `$1` / `${name}` in the replacement, `$$` for a literal `$`).

if vim.g.loaded_inhouse_find_replace then
  return
end
vim.g.loaded_inhouse_find_replace = true

local api = vim.api
local fn = vim.fn

local M = {}

local ns = api.nvim_create_namespace "inhouse_find_replace"
local ns_src = api.nvim_create_namespace "inhouse_find_replace_src"

local DEBOUNCE_MS = 120
local MAX_SRC_HL = 2000

local ORDER = { "search", "replace", "flags", "results" }
local INPUTS = { search = true, replace = true, flags = true }

-- Flags that would break the way we drive rg.
local BLOCKED = {
  ["--json"] = true,
  ["--passthru"] = true,
  ["--files"] = true,
  ["--files-with-matches"] = true,
  ["--files-without-match"] = true,
  ["--count"] = true,
  ["--count-matches"] = true,
  ["--only-matching"] = true,
  ["--vimgrep"] = true,
  ["--replace"] = true,
  ["-r"] = true,
  ["-l"] = true,
  ["-c"] = true,
  ["-o"] = true,
}

local TOGGLES = {
  ignore_case = { "--ignore-case", "-i" },
  word = { "--word-regexp", "-w" },
  fixed = { "--fixed-strings", "-F" },
}

local state = nil

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function setup_highlights()
  local function link(name, target)
    api.nvim_set_hl(0, name, { link = target, default = true })
  end
  link("FindReplaceOld", "DiffDelete")
  link("FindReplaceNew", "DiffAdd")
  link("FindReplaceLnum", "LineNr")
  link("FindReplaceSkipped", "Comment")
  link("FindReplaceMatch", "Search")
  link("FindReplaceActive", "Special")
  link("FindReplaceError", "ErrorMsg")
end

local function notify(message, level)
  vim.notify("FindReplace: " .. message, level or vim.log.levels.INFO)
end

local function get_input(s, name)
  local buf = s.bufs[name]
  if not buf or not api.nvim_buf_is_valid(buf) then
    return ""
  end
  return table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "")
end

local function set_input(s, name, value)
  api.nvim_buf_set_lines(s.bufs[name], 0, -1, false, { (tostring(value or ""):gsub("\n", " ")) })
end

local function parse_flags(s)
  local flags = {}
  for tok in get_input(s, "flags"):gmatch "%S+" do
    if tok:sub(1, 1) == "-" and not BLOCKED[tok] and not tok:match "^%-%-replace" then
      flags[#flags + 1] = tok
    end
  end
  return flags
end

local function region_lines(s)
  if not api.nvim_buf_is_valid(s.src_buf) then
    return {}
  end
  return api.nvim_buf_get_lines(s.src_buf, s.first - 1, s.last, false)
end

local function to_stdin(lines)
  return table.concat(lines, "\n") .. "\n"
end

local function split_output(stdout)
  local out = vim.split(stdout or "", "\n", { plain = true })
  if out[#out] == "" then
    out[#out] = nil
  end
  return out
end

local function base_cmd(flags)
  -- --smart-case comes first so user flags (-i / -s / -S) override it.
  local cmd = { "rg", "--color", "never", "--smart-case" }
  vim.list_extend(cmd, flags)
  return cmd
end

local function replace_cmd(flags, query, replacement)
  local cmd = base_cmd(flags)
  vim.list_extend(cmd, {
    "--passthru",
    "--no-line-number",
    "--replace=" .. replacement,
    "--",
    query,
    "-",
  })
  return cmd
end

local function parse_json(stdout, lines)
  local matches = {}
  for _, raw in ipairs(vim.split(stdout or "", "\n", { plain = true, trimempty = true })) do
    local ok, ev = pcall(vim.json.decode, raw)
    if ok and type(ev) == "table" and ev.type == "match" then
      local lnum = ev.data.line_number
      local subs = {}
      for _, sm in ipairs(ev.data.submatches or {}) do
        subs[#subs + 1] = { sm.start, sm["end"] }
      end
      matches[#matches + 1] = { lnum = lnum, subs = subs, text = lines[lnum] or "" }
    end
  end
  return matches
end

----------------------------------------------------------------------
-- layout
----------------------------------------------------------------------

local function results_title(s)
  if s.error then
    return " Error "
  end
  local occurrences = 0
  for _, m in ipairs(s.matches) do
    occurrences = occurrences + #m.subs
  end
  local title = (" Results: %d match%s in %d line%s "):format(occurrences, occurrences == 1 and "" or "es", #s.matches, #s.matches == 1 and "" or "s")
  if s.first > 1 or s.last ~= -1 then
    title = title .. ("[lines %d-%s] "):format(s.first, s.last == -1 and "$" or tostring(s.last))
  end
  return title
end

local function win_cfg(s, name)
  local cols = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight
  local outer_w = math.min(cols, math.max(60, math.floor(cols * 0.7)))
  local res_h = math.max(5, math.min(math.floor(rows * 0.4), rows - 13))
  local total = 9 + res_h + 2
  local top = math.max(0, math.floor((rows - total) / 2))
  local left = math.floor((cols - outer_w) / 2)

  local cfg = {
    relative = "editor",
    col = left,
    width = math.max(10, outer_w - 2),
    height = 1,
    border = "rounded",
    style = "minimal",
    title_pos = "left",
  }

  if name == "search" then
    cfg.row = top
    cfg.title = " Search "
  elseif name == "replace" then
    cfg.row = top + 3
    cfg.title = " Replace "
  elseif name == "flags" then
    cfg.row = top + 6
    cfg.title = " Flags   <A-i> ignore case · <A-w> word · <A-f> fixed "
  else
    cfg.row = top + 9
    cfg.height = res_h
    cfg.title = results_title(s)
    cfg.footer = " <C-s> replace all · r this line · <Space> skip · <CR> go to · <Tab> next · q close "
    cfg.footer_pos = "center"
  end

  return cfg
end

local function update_borders(s)
  local cur = api.nvim_get_current_win()
  for _, win in pairs(s.wins) do
    if api.nvim_win_is_valid(win) then
      local hl = win == cur and "FindReplaceActive" or "FloatBorder"
      vim.wo[win].winhighlight = ("FloatBorder:%s,FloatTitle:%s"):format(hl, hl)
    end
  end
end

----------------------------------------------------------------------
-- rendering
----------------------------------------------------------------------

local function highlight_source(s)
  if not api.nvim_buf_is_valid(s.src_buf) then
    return
  end
  api.nvim_buf_clear_namespace(s.src_buf, ns_src, 0, -1)
  for i, m in ipairs(s.matches) do
    if i > MAX_SRC_HL then
      break
    end
    local row = s.first - 2 + m.lnum
    for _, sub in ipairs(m.subs) do
      pcall(api.nvim_buf_set_extmark, s.src_buf, ns_src, row, sub[1], {
        end_col = sub[2],
        hl_group = "FindReplaceMatch",
        priority = 200,
      })
    end
  end
end

local function render(s)
  local buf = s.bufs.results
  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local out, marks = {}, {}
  s.row_to_match = {}

  if s.error then
    for _, l in ipairs(vim.split(s.error, "\n", { plain = true })) do
      out[#out + 1] = l
      marks[#marks + 1] = { #out - 1, 0, #l, "FindReplaceError" }
    end
  elseif get_input(s, "search") == "" then
    out = { "(type a search pattern)" }
  elseif #s.matches == 0 then
    out = { "(no matches)" }
  else
    local last = s.matches[#s.matches].lnum + s.first - 1
    local w = #tostring(last)
    local blank = (" "):rep(w)

    for i, m in ipairs(s.matches) do
      local skipped = s.skipped[m.lnum]
      local prefix = ("%" .. w .. "d │ "):format(m.lnum + s.first - 1)

      out[#out + 1] = prefix .. m.text
      s.row_to_match[#out] = i
      local row = #out - 1

      marks[#marks + 1] = { row, 0, #prefix, "FindReplaceLnum" }
      if skipped then
        marks[#marks + 1] = { row, #prefix, #out[#out], "FindReplaceSkipped" }
      else
        for _, sub in ipairs(m.subs) do
          marks[#marks + 1] = { row, #prefix + sub[1], #prefix + sub[2], "FindReplaceOld" }
        end
      end

      local new = s.previews and s.previews[m.lnum]
      if new and new ~= m.text then
        local prefix2 = blank .. " → "
        out[#out + 1] = prefix2 .. new
        s.row_to_match[#out] = i
        row = #out - 1
        marks[#marks + 1] = { row, 0, #prefix2, "FindReplaceLnum" }
        marks[#marks + 1] = { row, #prefix2, #out[#out], skipped and "FindReplaceSkipped" or "FindReplaceNew" }
      end
    end

    if s.note then
      out[#out + 1] = ""
      out[#out + 1] = s.note
      marks[#marks + 1] = { #out - 1, 0, #s.note, "WarningMsg" }
    end
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modifiable = false

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mk in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, buf, ns, mk[1], mk[2], {
      end_col = mk[3],
      hl_group = mk[4],
      priority = 100,
    })
  end

  local win = s.wins.results
  if win and api.nvim_win_is_valid(win) then
    local row = api.nvim_win_get_cursor(win)[1]
    pcall(api.nvim_win_set_cursor, win, { math.max(1, math.min(row, #out)), 0 })
    pcall(api.nvim_win_set_config, win, win_cfg(s, "results"))
  end

  highlight_source(s)
end

----------------------------------------------------------------------
-- searching
----------------------------------------------------------------------

local function search(s)
  if state ~= s then
    return
  end

  s.seq = s.seq + 1
  local seq = s.seq

  local query = get_input(s, "search")
  local replacement = get_input(s, "replace")

  s.matches, s.previews, s.error, s.note = {}, nil, nil, nil

  if query == "" then
    render(s)
    return
  end

  local lines = region_lines(s)
  local stdin = to_stdin(lines)
  local flags = parse_flags(s)

  local cmd = base_cmd(flags)
  vim.list_extend(cmd, { "--json", "--", query, "-" })

  vim.system(cmd, { stdin = stdin, text = true }, function(res)
    vim.schedule(function()
      if state ~= s or s.seq ~= seq then
        return
      end

      if res.code > 1 then
        local err = vim.trim(res.stderr or "")
        s.error = err ~= "" and err or "ripgrep failed"
        render(s)
        return
      end

      s.matches = parse_json(res.stdout, lines)

      if replacement == "" or #s.matches == 0 then
        render(s)
        return
      end

      vim.system(replace_cmd(flags, query, replacement), { stdin = stdin, text = true }, function(r2)
        vim.schedule(function()
          if state ~= s or s.seq ~= seq then
            return
          end

          if r2.code > 1 then
            local err = vim.trim(r2.stderr or "")
            s.error = err ~= "" and err or "ripgrep failed"
          else
            local out = split_output(r2.stdout)
            if #out == #lines then
              s.previews = out
            else
              s.note = "Replacement changes the line count (multiline?) - preview/apply disabled."
            end
          end

          render(s)
        end)
      end)
    end)
  end)
end

local function schedule_search(s)
  if not s.timer then
    s.timer = vim.uv.new_timer()
  end
  s.timer:stop()
  s.timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      if state == s then
        search(s)
      end
    end)
  )
end

----------------------------------------------------------------------
-- applying
----------------------------------------------------------------------

-- Re-runs rg synchronously so the result is never stale, then rewrites only
-- the changed, non-skipped lines (optionally just one) in the source buffer.
local function apply(s, only_lnum)
  local query = get_input(s, "search")
  if query == "" then
    notify("Enter a search pattern first.", vim.log.levels.WARN)
    return
  end

  local replacement = get_input(s, "replace")
  if replacement == "" then
    local choice = fn.confirm("Replace matches with an empty string?", "&Replace\n&Cancel", 2)
    if choice ~= 1 then
      return
    end
  end

  local lines = region_lines(s)
  local res = vim
    .system(replace_cmd(parse_flags(s), query, replacement), {
      stdin = to_stdin(lines),
      text = true,
    })
    :wait()

  if res.code > 1 then
    notify(vim.trim(res.stderr or "ripgrep failed"), vim.log.levels.ERROR)
    return
  end

  local out = split_output(res.stdout)
  if #out ~= #lines then
    notify("Replacement changes the line count; not supported.", vim.log.levels.WARN)
    return
  end

  local changed = 0
  local ok, err = pcall(function()
    for i, old in ipairs(lines) do
      if out[i] ~= old and not s.skipped[i] and (not only_lnum or only_lnum == i) then
        local row = s.first - 1 + i - 1
        api.nvim_buf_set_lines(s.src_buf, row, row + 1, false, { out[i] })
        changed = changed + 1
      end
    end
  end)

  if not ok then
    notify(tostring(err), vim.log.levels.ERROR)
    return
  end

  if not only_lnum then
    s.skipped = {}
  end

  notify(("replaced in %d line%s."):format(changed, changed == 1 and "" or "s"))
  search(s)
end

----------------------------------------------------------------------
-- window management
----------------------------------------------------------------------

local function close(s)
  if s.closing then
    return
  end
  s.closing = true

  pcall(api.nvim_del_augroup_by_id, s.augroup)

  if s.timer then
    s.timer:stop()
    if not s.timer:is_closing() then
      s.timer:close()
    end
    s.timer = nil
  end

  if api.nvim_buf_is_valid(s.src_buf) then
    api.nvim_buf_clear_namespace(s.src_buf, ns_src, 0, -1)
  end

  for _, name in ipairs(ORDER) do
    local win = s.wins[name]
    if win and api.nvim_win_is_valid(win) then
      pcall(api.nvim_win_close, win, true)
    end
  end

  if state == s then
    state = nil
  end

  vim.cmd "stopinsert"
  if api.nvim_win_is_valid(s.src_win) then
    pcall(api.nvim_set_current_win, s.src_win)
  end
end

local function focus(s, name)
  local win = s.wins[name]
  if not win or not api.nvim_win_is_valid(win) then
    return
  end
  api.nvim_set_current_win(win)
  if INPUTS[name] then
    local line = api.nvim_buf_get_lines(s.bufs[name], 0, 1, false)[1] or ""
    api.nvim_win_set_cursor(win, { 1, #line })
    vim.cmd "startinsert!"
  else
    vim.cmd "stopinsert"
  end
end

local function current_name(s)
  local cur = api.nvim_get_current_win()
  for name, win in pairs(s.wins) do
    if win == cur then
      return name
    end
  end
end

local function cycle(s, dir)
  local name = current_name(s) or "search"
  local idx = 1
  for i, n in ipairs(ORDER) do
    if n == name then
      idx = i
    end
  end
  idx = ((idx - 1 + dir) % #ORDER) + 1
  focus(s, ORDER[idx])
end

local function cursor_match(s)
  local row = api.nvim_win_get_cursor(s.wins.results)[1]
  return s.matches[s.row_to_match[row] or 0]
end

local function goto_match(s)
  local m = cursor_match(s)
  if not m then
    return
  end
  local win, first = s.src_win, s.first
  close(s)
  if api.nvim_win_is_valid(win) then
    api.nvim_set_current_win(win)
    pcall(api.nvim_win_set_cursor, win, { first - 1 + m.lnum, m.subs[1] and m.subs[1][1] or 0 })
    vim.cmd "normal! zz"
  end
end

local function reveal(s)
  if not api.nvim_win_is_valid(s.src_win) then
    return
  end
  local m = cursor_match(s)
  if not m then
    return
  end
  pcall(api.nvim_win_set_cursor, s.src_win, { s.first - 1 + m.lnum, m.subs[1] and m.subs[1][1] or 0 })
  api.nvim_win_call(s.src_win, function()
    vim.cmd "normal! zz"
  end)
end

local function toggle_skip(s)
  local m = cursor_match(s)
  if not m then
    return
  end
  s.skipped[m.lnum] = not s.skipped[m.lnum] or nil
  render(s)
end

local function toggle_flag(s, key)
  local aliases = TOGGLES[key]
  local tokens, found = {}, false
  for tok in get_input(s, "flags"):gmatch "%S+" do
    if vim.tbl_contains(aliases, tok) then
      found = true
    else
      tokens[#tokens + 1] = tok
    end
  end
  if not found then
    tokens[#tokens + 1] = aliases[1]
  end
  set_input(s, "flags", table.concat(tokens, " "))
  s.skipped = {}
  schedule_search(s)
end

----------------------------------------------------------------------
-- open
----------------------------------------------------------------------

local function new_buf(ft)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = ft
  return buf
end

local function setup_keymaps(s)
  local function map(name, modes, lhs, rhs, desc)
    vim.keymap.set(modes, lhs, rhs, {
      buffer = s.bufs[name],
      nowait = true,
      silent = true,
      desc = "FindReplace: " .. desc,
    })
  end

  local function later(f)
    return function()
      vim.schedule(f)
    end
  end

  for _, name in ipairs(ORDER) do
    map(
      name,
      { "n", "i" },
      "<Tab>",
      later(function()
        cycle(s, 1)
      end),
      "next field"
    )
    map(
      name,
      { "n", "i" },
      "<S-Tab>",
      later(function()
        cycle(s, -1)
      end),
      "previous field"
    )
    map(
      name,
      { "n", "i" },
      "<C-s>",
      later(function()
        apply(s)
      end),
      "replace all"
    )
    map(name, { "n", "i" }, "<A-i>", function()
      toggle_flag(s, "ignore_case")
    end, "toggle ignore case")
    map(name, { "n", "i" }, "<A-w>", function()
      toggle_flag(s, "word")
    end, "toggle whole word")
    map(name, { "n", "i" }, "<A-f>", function()
      toggle_flag(s, "fixed")
    end, "toggle fixed strings")
    map(name, "n", "q", function()
      close(s)
    end, "close")
    map(name, "n", "<Esc>", function()
      close(s)
    end, "close")
  end

  -- <CR> in an input moves down a field; after the last input it jumps to results.
  for _, name in ipairs { "search", "replace", "flags" } do
    map(
      name,
      { "n", "i" },
      "<CR>",
      later(function()
        focus(s, name == "search" and "replace" or name == "replace" and "flags" or "results")
      end),
      "next field"
    )
  end

  map("results", "n", "<CR>", function()
    goto_match(s)
  end, "go to match")
  map("results", "n", "<Space>", function()
    toggle_skip(s)
  end, "skip / unskip match")
  map("results", "n", "r", function()
    local m = cursor_match(s)
    if m then
      apply(s, m.lnum)
    end
  end, "replace this line only")
  map(
    "results",
    "n",
    "i",
    later(function()
      focus(s, "search")
    end),
    "edit search"
  )
end

function M.open(opts)
  opts = opts or {}

  if fn.executable "rg" ~= 1 then
    notify("ripgrep (rg) is not installed.", vim.log.levels.ERROR)
    return
  end

  if state then
    focus(state, "search")
    return
  end

  setup_highlights()

  local s = {
    src_buf = api.nvim_get_current_buf(),
    src_win = api.nvim_get_current_win(),
    first = opts.line1 or 1,
    last = opts.line2 or -1,
    wins = {},
    bufs = {},
    matches = {},
    skipped = {},
    row_to_match = {},
    seq = 0,
  }
  state = s

  for _, name in ipairs(ORDER) do
    s.bufs[name] = new_buf(name == "results" and "find-replace" or "find-replace-input")
  end

  set_input(s, "search", opts.search or "")
  set_input(s, "replace", opts.replace or "")
  set_input(s, "flags", opts.flags or "")
  api.nvim_buf_set_lines(s.bufs.results, 0, -1, false, { "(type a search pattern)" })
  vim.bo[s.bufs.results].modifiable = false

  for _, name in ipairs(ORDER) do
    s.wins[name] = api.nvim_open_win(s.bufs[name], false, win_cfg(s, name))
    vim.wo[s.wins[name]].wrap = false
  end
  vim.wo[s.wins.results].cursorline = true

  setup_keymaps(s)

  s.augroup = api.nvim_create_augroup("FindReplaceUI", { clear = true })

  for name in pairs(INPUTS) do
    api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = s.augroup,
      buffer = s.bufs[name],
      callback = function()
        s.skipped = {}
        schedule_search(s)
      end,
    })
  end

  for _, win in pairs(s.wins) do
    api.nvim_create_autocmd("WinClosed", {
      group = s.augroup,
      pattern = tostring(win),
      callback = function()
        vim.schedule(function()
          close(s)
        end)
      end,
    })
  end

  api.nvim_create_autocmd("WinEnter", {
    group = s.augroup,
    callback = function()
      if state == s then
        update_borders(s)
      end
    end,
  })

  api.nvim_create_autocmd("VimResized", {
    group = s.augroup,
    callback = function()
      if state ~= s then
        return
      end
      for _, name in ipairs(ORDER) do
        pcall(api.nvim_win_set_config, s.wins[name], win_cfg(s, name))
      end
    end,
  })

  api.nvim_create_autocmd("CursorMoved", {
    group = s.augroup,
    buffer = s.bufs.results,
    callback = function()
      if state == s then
        reveal(s)
      end
    end,
  })

  focus(s, "search")
  update_borders(s)

  if get_input(s, "search") ~= "" then
    search(s)
  end
end

----------------------------------------------------------------------
-- commands
----------------------------------------------------------------------

api.nvim_create_user_command("FindReplace", function(args)
  local opts = {}
  if args.range > 0 then
    opts.line1, opts.line2 = args.line1, args.line2
  end
  if args.args ~= "" then
    opts.search = args.args
  end
  M.open(opts)
end, {
  range = true,
  nargs = "?",
  desc = "Open find and replace popup for this buffer (or a line range)",
})

api.nvim_create_user_command("FindReplaceWord", function()
  M.open {
    search = fn.expand "<cword>",
    flags = "--fixed-strings --word-regexp",
  }
end, { desc = "Find and replace the word under the cursor in this buffer" })

return M
