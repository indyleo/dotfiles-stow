-- See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Master-Layout/ for more
hl.config({
    master = {
        new_status = "slave",
    },
})

-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({
    misc = {
        force_default_wallpaper = -1,  -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})
