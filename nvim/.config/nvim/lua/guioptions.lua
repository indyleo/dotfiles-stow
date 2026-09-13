-- guioptions.lua
-- Only loaded when running under Neovide (see init.lua's vim.g.neovide guard).
local gopt = vim.g
local opt = vim.opt

-- ========================
-- Window / title
-- ========================
opt.titlestring = "Neovide - %t (%{expand('%:p:h')})"
gopt.neovide_remember_window_size = true
gopt.neovide_theme = "auto" -- follow light/dark from your colorscheme

-- ========================
-- Font
-- ========================
opt.guifont = "CaskaydiaCove NF"

-- ========================
-- Transparency / blur
-- ========================
gopt.neovide_opacity = 0.85
gopt.neovide_normal_opacity = 0.85
gopt.neovide_floating_blur_amount_x = 2.0
gopt.neovide_floating_blur_amount_y = 2.0

-- ========================
-- Cursor animation
-- ========================
-- smear-cursor.nvim disables itself under Neovide (see pack.lua) since this
-- overlaps with it -- keep Neovide's own cursor doing the animating.
gopt.neovide_cursor_animation_length = 0.08
gopt.neovide_cursor_trail_size = 0.5
gopt.neovide_cursor_animate_in_insert_mode = true
gopt.neovide_cursor_animate_command_line = true
gopt.neovide_cursor_vfx_mode = "railgun" -- "", "railgun", "torpedo", "pixiedust", "sonicboom", "ripple", "wireframe"

-- ========================
-- Scrolling / performance
-- ========================
gopt.neovide_scroll_animation_length = 0.2
gopt.neovide_position_animation_length = 0.1
gopt.neovide_refresh_rate = 60
gopt.neovide_refresh_rate_idle = 5
gopt.neovide_no_idle = false -- true = always render at full rate (higher GPU/battery use)

-- ========================
-- Padding
-- ========================
gopt.neovide_padding_top = 0
gopt.neovide_padding_bottom = 0
gopt.neovide_padding_right = 0
gopt.neovide_padding_left = 0

-- ========================
-- Input
-- ========================
gopt.neovide_input_use_logo = true -- lets Cmd act as a modifier on macOS
gopt.neovide_input_macos_alt_is_meta = false

-- ========================
-- State for the toggle keymaps in keymaps.lua
-- ========================
gopt.neovide_scale_factor = gopt.neovide_scale_factor or 1.0
gopt.neovide_fullscreen = false
