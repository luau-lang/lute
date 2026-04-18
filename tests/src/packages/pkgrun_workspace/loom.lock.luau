return {
	version = 2,
	packages = {},
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
	dependencies = {
		["lib"] = {
			name = "lib",
			source = "packages/lib",
			sourceKind = "path",
			installPath = "packages/lib",
			dependencies = {},
		},
	},
}
