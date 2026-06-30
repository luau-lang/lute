return {
	version = 3,
	members = {
		["foo"] = {
			path = "packages/foo",
			dependencies = {},
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
	dependencies = {
		lib = "lib",
	},
}
