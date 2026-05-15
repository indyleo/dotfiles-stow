hl.config({
	animations = {
		enabled = true,

		-- --- Custom Bezier Curves ---
		bezier = {
			{ name = "fluid", points = { 0.22, 1, 0.36, 1 } },
			{ name = "snappy", points = { 0.1, 1, 0, 1 } },
			{ name = "overshot", points = { 0.05, 0.9, 0.1, 1.1 } },
			{ name = "bounce", points = { 0.1, 1.1, 0, 1 } },
		},

		-- --- Global Settings ---
		animation = {
			{ name = "global", enable = true, speed = 4, curve = "fluid" },

			-- --- Windows ---
			{ name = "windows", enable = true, speed = 4, curve = "overshot", style = "popin 80%" },
			{ name = "windowsIn", enable = true, speed = 3, curve = "overshot", style = "popin 80%" },
			{ name = "windowsOut", enable = true, speed = 3, curve = "fluid", style = "popin 80%" },
			{ name = "windowsMove", enable = true, speed = 3, curve = "snappy" },

			-- --- Layers ---
			{ name = "layers", enable = true, speed = 3, curve = "fluid", style = "fade" },
			{ name = "layersIn", enable = true, speed = 3, curve = "fluid", style = "fade" },
			{ name = "layersOut", enable = true, speed = 3, curve = "fluid", style = "fade" },

			-- --- Fading Effects ---
			{ name = "fade", enable = true, speed = 3, curve = "fluid" },

			-- --- Workspaces ---
			{ name = "workspaces", enable = true, speed = 4, curve = "fluid", style = "slidefade 70%" },

			-- --- Special Workspace ---
			{ name = "specialWorkspace", enable = true, speed = 3, curve = "bounce", style = "slidevert" },

			-- --- Extras ---
			{ name = "border", enable = true, speed = 4, curve = "fluid" },
			{ name = "zoomFactor", enable = true, speed = 3, curve = "fluid" },
		},
	},
})
