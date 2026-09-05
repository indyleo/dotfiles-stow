-- Rust filetype plugin --
-- See after/ftplugin/c.lua for why this no longer wraps in a BufEnter
-- autocmd on a shared, clearable augroup.
local keymap = vim.keymap.set
local bufnr = vim.api.nvim_get_current_buf()
local rsopts = function(desc)
  return { desc = "Rust: " .. desc, buffer = bufnr, noremap = true, silent = true }
end

local function cargo_cmd(cmd)
  vim.notify("🔧 Running cargo " .. cmd .. "...", vim.log.levels.INFO, { title = "Cargo" })

  local output = {}

  vim.fn.jobstart({ "cargo", cmd }, {
    stdout_buffered = true,
    stderr_buffered = true,

    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,

    on_stderr = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,

    on_exit = function(_, code)
      local msg = table.concat(output, "\n")

      if code == 0 then
        vim.notify("✅ cargo " .. cmd .. " succeeded:\n" .. msg, vim.log.levels.INFO, { title = "Cargo" })
      else
        vim.notify("❌ cargo " .. cmd .. " failed:\n" .. msg, vim.log.levels.ERROR, { title = "Cargo" })
      end
    end,
  })
end

keymap("n", "<leader>ra", function()
  vim.cmd.RustLsp "codeAction" -- supports rust-analyzer's grouping
end, rsopts "Code actions")

keymap(
  "n",
  "K", -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp { "hover", "actions" }
  end,
  rsopts "Hover actions"
)

keymap("n", "<leader>rb", function()
  cargo_cmd "build"
end, rsopts "Cargo build")

keymap("n", "<leader>rr", function()
  cargo_cmd "run"
end, rsopts "Cargo run")

keymap("n", "<leader>rc", function()
  cargo_cmd "check"
end, rsopts "Cargo check")

-- NOTE: this was previously mis-labeled "Cargo check" (copy-paste from the
-- keymap above) even though it runs `cargo test`. The key itself
-- (<leader>rt) was fine and is unchanged -- only the description was wrong.
keymap("n", "<leader>rt", function()
  cargo_cmd "test"
end, rsopts "Cargo test")
