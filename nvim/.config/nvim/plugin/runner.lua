-- plugin/runner.lua
-- One test runner for Rust, Go, Python, JS/TS and C/C++ projects. Commands run in
-- the project root through your existing :CommandRun floating terminal.
--
--   :TestRun    whole project        <leader>Tt
--   :TestFile   current file         <leader>Tf
--   :TestLast   repeat last command  <leader>Tl
--   :TestInfo   show what would run

local last_cmd

local function root_with(markers)
  return vim.fs.root(0, markers)
end

-- Returns { root = ..., project = cmd, file = cmd-or-nil } or nil
local function detect()
  local file = vim.fn.expand "%:p"
  local q = vim.fn.shellescape(file)
  local r

  r = root_with { "Cargo.toml" }
  if r then
    return { root = r, project = "cargo test", file = "cargo test" }
  end

  r = root_with { "go.mod" }
  if r then
    local dir = vim.fn.shellescape(vim.fn.expand "%:p:h")
    return { root = r, project = "go test ./...", file = "go test " .. dir }
  end

  r = root_with { "pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini", "requirements.txt" }
  if r then
    return { root = r, project = "python -m pytest", file = "python -m pytest " .. q }
  end

  r = root_with { "package.json" }
  if r then
    return { root = r, project = "npm test --silent", file = "npx --no-install jest " .. q }
  end

  r = root_with { "CMakeLists.txt" }
  if r then
    return { root = r, project = "cmake --build build && ctest --test-dir build --output-on-failure" }
  end

  r = root_with { "Makefile", "makefile" }
  if r then
    return { root = r, project = "make test" }
  end
end

local function run(cmd, root)
  last_cmd = { cmd = cmd, root = root }
  vim.cmd.CommandRun("cd " .. vim.fn.shellescape(root) .. " && " .. cmd)
end

local function with_project(kind)
  local d = detect()
  if not d then
    vim.notify("No test setup detected (Cargo, Go, pytest, npm, CMake, Make)", vim.log.levels.WARN)
    return
  end
  local cmd = d[kind] or d.project
  if kind == "file" and not d.file then
    vim.notify("No per-file test command for this project; running the whole suite", vim.log.levels.INFO)
  end
  run(cmd, d.root)
end

vim.api.nvim_create_user_command("TestRun", function()
  with_project "project"
end, { desc = "Run the project's tests" })

vim.api.nvim_create_user_command("TestFile", function()
  with_project "file"
end, { desc = "Run tests for the current file" })

vim.api.nvim_create_user_command("TestLast", function()
  if not last_cmd then
    vim.notify("No previous test command", vim.log.levels.WARN)
    return
  end
  run(last_cmd.cmd, last_cmd.root)
end, { desc = "Repeat the last test command" })

vim.api.nvim_create_user_command("TestInfo", function()
  local d = detect()
  if not d then
    vim.notify("No test setup detected", vim.log.levels.WARN)
    return
  end
  vim.notify(("root: %s\nproject: %s\nfile: %s"):format(d.root, d.project, d.file or "(same as project)"), vim.log.levels.INFO)
end, { desc = "Show detected test commands" })

vim.keymap.set("n", "<leader>Tt", "<cmd>TestRun<CR>", { desc = "Test: project" })
vim.keymap.set("n", "<leader>Tf", "<cmd>TestFile<CR>", { desc = "Test: current file" })
vim.keymap.set("n", "<leader>Tl", "<cmd>TestLast<CR>", { desc = "Test: repeat last" })
