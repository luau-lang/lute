return {
	version = 3,
	dependencies = {
		app = "app",
	},
	packages = {
		["app"] = {
			name = "app",
			source = "packages/app",
			sourceKind = "path",
			installPath = "packages/app",
			dependencies = {
				lib = "lib",
				shared = "shared",
			},
		},
		["lib"] = {
			name = "lib",
			source = "packages/lib",
			sourceKind = "path",
			installPath = "packages/lib",
			dependencies = {
				utils = "shared",
				h = "helpers",
			},
		},
		["shared"] = {
			name = "shared",
			source = "packages/shared",
			sourceKind = "path",
			installPath = "packages/shared",
			dependencies = {},
		},
		["helpers"] = {
			name = "helpers",
			source = "packages/helpers",
			sourceKind = "path",
			installPath = "packages/helpers",
			dependencies = {},
		},
	},
}
