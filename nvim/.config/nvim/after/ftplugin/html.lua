-- HTML filetype plugin --
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("HTMLMaps", { clear = true }),
  callback = function(args)
    local keymap = vim.keymap.set
    local bufnr = args.buf
    local htmlopts = function(desc)
      return { desc = "HTML: " .. desc, buffer = bufnr, noremap = true, silent = true }
    end
    vim.bo[bufnr].expandtab = false -- Use tabs instead of spaces
    vim.bo[bufnr].tabstop = 2 -- Width of a tab character
    vim.bo[bufnr].shiftwidth = 2 -- Indentation width
    vim.bo[bufnr].softtabstop = 2 -- Editing width of a tab
    vim.bo[bufnr].matchpairs = "(:),{:},[:],<:>" -- Jump between opening/closing tag using %

    -- Insert HTML5 boilerplate
    keymap("n", "<leader>ht", function()
      local lines = {
        "<!DOCTYPE html>",
        '<html lang="en">',
        "<head>",
        '  <meta charset="UTF-8">',
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
        "  <title>Document</title>",
        "</head>",
        "<body>",
        "",
        "</body>",
        "</html>",
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, lines)
    end, htmlopts "Insert HTML5 template")

    keymap("n", "<leader>hw", function()
      local cwd = vim.fn.getcwd()
      local script = "httptoggle"
      local cmd = string.format("bash %s '%s'", script, cwd)

      vim.fn.jobstart({ "bash", "-c", cmd }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          for _, line in ipairs(data) do
            if line ~= "" then
              vim.notify("[HTTP] " .. line, vim.log.levels.INFO)
            end
          end
        end,
        on_stderr = function(_, data)
          for _, line in ipairs(data) do
            if line ~= "" then
              vim.notify("[HTTP ERROR] " .. line, vim.log.levels.ERROR)
            end
          end
        end,
      })
    end, htmlopts "Toggle HTTP Server & Open in browser")
  end,
})
