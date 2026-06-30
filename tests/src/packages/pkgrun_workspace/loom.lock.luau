return {
	version = 3,
	members = {
		["lib"] = {
			path = "packages/lib",
			dependencies = {},
		},
		["app"] = {
			path = "packages/app",
			dependencies = {
				lib = "lib",
			},
		},
	},
	packages = {
		["lib"] = {
			name = "lib",
			source = "packages/lib",
			sourceKind = "path",
			installPath = "packages/lib",
			dependencies = {},
		},
	},
	dependencies = {},
}
