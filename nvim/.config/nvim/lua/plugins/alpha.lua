---@diagnostic disable: undefined-field
return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require "alpha"
    local dashboard = require "alpha.themes.dashboard"

    -- Set header
    if vim.g.neovide then
      dashboard.section.header.val = {
        "                                                         ",
        " ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗██████╗ ███████╗ ",
        " ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║██╔══██╗██╔════╝ ",
        " ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██║  ██║█████╗   ",
        " ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║  ██║██╔══╝   ",
        " ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██████╔╝███████╗ ",
        " ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═════╝ ╚══════╝ ",
        "                                                         ",
      }
    else
      dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
        "                                                     ",
      }
    end
    -- Set menu
    dashboard.section.buttons.val = {
      dashboard.button("e", "  > New File", ":ene <BAR> startinsert <CR>"),
      dashboard.button("SPC ee", "  > File explorer", ":Oil --float<CR>"),
      dashboard.button("SPC ff", "󰱼  > Find File", ":Telescope find_files<CR>"),
      dashboard.button("SPC fs", "󰅳  > Find String", ":Telescope live_grep<CR>"),
      dashboard.button("SPC fh", "󰞋  > Find Help", ":Telescope help_tags<CR>"),
      dashboard.button("cd", "  > Config DWM", ":EditFile ~/Github/suckless/dwm/ config.def.h<CR>"),
      dashboard.button("ck", "  > Config Sxhkd", ":EditFile ~/.config/sxhkd/ sxhkdrc<CR>"),
      dashboard.button("cm", "  > Config Dmenu", ":EditFile ~/Github/suckless/dmenu/ config.def.h<CR>"),
      dashboard.button("cl", "  > Config Slock", ":EditFile ~/Github/suckless/slock/ config.def.h<CR>"),
      dashboard.button("ct", "  > Config St", ":EditFile ~/Github/suckless/st/ config.def.h<CR>"),
      dashboard.button("ce", "  > Config Nvim", ":OilDir $XDG_CONFIG_HOME/nvim<CR>"),
      dashboard.button("cz", "  > Config Zsh", ":EditFile ~/.config/zsh/ .zshrc<CR>"),
      dashboard.button("cp", "  > Config Prompt", ":EditFile ~/.config/shell/ prompt.zsh<CR>"),
      dashboard.button("cf", "󰌢  > Config FastFetch", ":EditFile ~/.config/fastfetch/ config.jsonc<CR>"),
      dashboard.button("cy", "󰇥  > Config LF", ":OilDir $XDG_CONFIG_HOME/lf<CR>"),
      dashboard.button("q", "  > Quit Nvim", ":qa!<CR>"),
      dashboard.button("SPC l", "󰒲  > Lazy", ":Lazy<CR>"),
    }

    -- Send config to alpha
    alpha.setup(dashboard.opts)

    -- Disable folding on alpha buffer
    vim.cmd [[autocmd FileType alpha setlocal nofoldenable]]
  end,
}
