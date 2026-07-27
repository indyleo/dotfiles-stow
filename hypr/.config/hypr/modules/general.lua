hl.config({
	general = {
		gaps_in = 10,
		gaps_out = 10,

		border_size = 3,

		-- Gruvbox Theme Colors
		["col.active_border"] = { colors = { "rgba(83a598ee)", "rgba(d3869bee)" }, angle = 45 },
		["col.inactive_border"] = "rgba(504945aa)",

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		allow_tearing = false,

		layout = "master",
	},
})
