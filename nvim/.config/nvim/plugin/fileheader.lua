-- plugin/fileheader.lua
-- Automatically loaded by Neovim when placed in `plugin/`

------------------------------------------------------------
-- Function: Insert file header at top of buffer
------------------------------------------------------------
local function insert_file_header()
  if not vim.bo.modifiable then
    return
  end

  local user = os.getenv "USER" or os.getenv "USERNAME" or "unknown"
  local date_time = os.date "%A %B %d, %Y, %I:%M %p"
  local file_type = vim.bo.filetype or "unknown"

  -- Map filetypes to comment syntax
  local comment_styles = {
    python = "#",
    bash = "#",
    zsh = "#",
    fish = "#",
    sh = "#",
    ps1 = "#",
    jsonc = "#",
    yaml = "#",
    toml = "#",
    make = "#",
    dockerfile = "#",
    ini = "#",
    perl = "#",

    javascript = "//",
    typescript = "//",
    c = "//",
    cpp = "//",
    rust = "//",
    java = "//",
    kotlin = "//",
    r = "//",
    swift = "//",
    scala = "//",
    groovy = "//",
    glsl = "//",
    arduino = "//",

    html = { "<!--", "-->" },
    xml = { "<!--", "-->" },
    markdown = { "<!--", "-->" },
    css = { "/*", "*/" },
    scss = { "/*", "*/" },
    less = { "/*", "*/" },

    lua = "--",
    vim = '"',
    autohotkey = ";",
    assembly = ";",
    lisp = ";",
    scheme = ";",
    clojure = ";",
    elisp = ";",
    tcl = "#",
    sql = "--",
    haskell = "--",
    ada = "--",
    rebol = ";",
    fortran = "!",
    erlang = "%",
    prolog = "%",
    fsharp = "//",
    ocaml = { "(*", "*)" },
    coq = { "(*", "*)" },
    sml = { "(*", "*)" },
  }

  local comment = comment_styles[file_type] or "#"

  local header
  if type(comment) == "table" then
    header = string.format("%s By: %s | %s | %s %s", comment[1], user, date_time, file_type, comment[2])
  else
    header = string.format("%s By: %s | %s | %s", comment, user, date_time, file_type)
  end

  vim.api.nvim_buf_set_lines(0, 0, 0, false, { header })
end

------------------------------------------------------------
-- User Command
------------------------------------------------------------
vim.api.nvim_create_user_command("FileHeader", function()
  insert_file_header()
end, {
  nargs = 0,
  desc = "Insert file header at top of buffer",
})
