return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    fzf_opts = {
      ["--ansi"] = true,
      ["--tabstop"] = "2",
    },
    file_icon_padding = " ",
    winopts = {
      split = "belowright 15new",
    },
  },
}
