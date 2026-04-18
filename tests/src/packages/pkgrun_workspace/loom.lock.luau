return {
	version = 2,
	packages = {},
	members = {
		["lib"] = {
			path = "packages/lib",
			packages = {},
		},
		["app"] = {
			path = "packages/app",
			packages = { "lib" },
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
