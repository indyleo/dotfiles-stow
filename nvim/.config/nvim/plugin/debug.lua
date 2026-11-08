-- plugin/debug.lua
-- Debugging with nvim-dap + dap-ui. Does nothing until the plugins are installed
-- (restart Neovim once after the first `vim.pack` install and :MasonToolsInstall).
--
-- Keys:  F5 continue   F6 step over   F7 step into   F8 step out   F9 breakpoint
--        <leader>bb breakpoint   bB conditional   bc continue   bo/bi/bO over/into/out
--        bu toggle UI   br REPL   bl run last   bx terminate   be eval (n, v)

local ok, dap = pcall(require, "dap")
if not ok then
  return
end

-- ── UI ───────────────────────────────────────────────────────────────────
local ui_ok, dapui = pcall(require, "dapui")
if ui_ok then
  dapui.setup()
  dap.listeners.before.attach.dapui_config = dapui.open
  dap.listeners.before.launch.dapui_config = dapui.open
  dap.listeners.before.event_terminated.dapui_config = dapui.close
  dap.listeners.before.event_exited.dapui_config = dapui.close
end

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

-- ── Adapters ─────────────────────────────────────────────────────────────
-- Mason puts its bin directory on PATH, so these resolve once installed.

-- C / C++ / Rust (codelldb)
dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = { command = "codelldb", args = { "--port", "${port}" } },
}
local function ask_executable()
  return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
end
local native = {
  {
    name = "Launch executable",
    type = "codelldb",
    request = "launch",
    program = ask_executable,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
}
dap.configurations.c = native
dap.configurations.cpp = native
dap.configurations.rust = native

-- Go (delve)
dap.adapters.delve = {
  type = "server",
  port = "${port}",
  executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
}
dap.configurations.go = {
  { type = "delve", name = "Debug file", request = "launch", program = "${file}" },
  { type = "delve", name = "Debug package tests", request = "launch", mode = "test", program = "${fileDirname}" },
}

-- Python (debugpy installed by Mason)
local py_ok, dap_python = pcall(require, "dap-python")
if py_ok then
  local debugpy_python = vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python"
  if vim.uv.fs_stat(debugpy_python) then
    dap_python.setup(debugpy_python)
  end
end

-- ── Keymaps ──────────────────────────────────────────────────────────────
local function map(lhs, rhs, desc, mode)
  vim.keymap.set(mode or "n", lhs, rhs, { desc = "Debug: " .. desc })
end

map("<F5>", dap.continue, "continue / start")
map("<F6>", dap.step_over, "step over")
map("<F7>", dap.step_into, "step into")
map("<F8>", dap.step_out, "step out")
map("<F9>", dap.toggle_breakpoint, "toggle breakpoint")

map("<leader>bb", dap.toggle_breakpoint, "toggle breakpoint")
map("<leader>bB", function()
  dap.set_breakpoint(vim.fn.input "Breakpoint condition: ")
end, "conditional breakpoint")
map("<leader>bc", dap.continue, "continue / start")
map("<leader>bo", dap.step_over, "step over")
map("<leader>bi", dap.step_into, "step into")
map("<leader>bO", dap.step_out, "step out")
map("<leader>br", dap.repl.toggle, "toggle REPL")
map("<leader>bl", dap.run_last, "run last")
map("<leader>bx", dap.terminate, "terminate")
if ui_ok then
  map("<leader>bu", dapui.toggle, "toggle UI")
  map("<leader>be", dapui.eval, "evaluate expression", { "n", "v" })
end
