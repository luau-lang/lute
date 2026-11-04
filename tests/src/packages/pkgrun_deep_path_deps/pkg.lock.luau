return {
	version = 5,
	dependencies = {
		app = "app",
	},
	packages = {
		["app"] = {
			name = "app",
			source = "packages/app",
			sourceKind = "path",
			installPath = "packages/app/src",
			dependencies = {
				lib = "lib",
				shared = "shared",
			},
		},
		["lib"] = {
			name = "lib",
			source = "packages/lib",
			sourceKind = "path",
			installPath = "packages/lib/src",
			dependencies = {
				utils = "shared",
				h = "helpers",
			},
		},
		["shared"] = {
			name = "shared",
			source = "packages/shared",
			sourceKind = "path",
			installPath = "packages/shared/src",
			dependencies = {},
		},
		["helpers"] = {
			name = "helpers",
			source = "packages/helpers",
			sourceKind = "path",
			installPath = "packages/helpers/src",
			dependencies = {},
		},
	},
}
