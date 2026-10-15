return {
	version = 3,
	dependencies = {
		first = "first",
		second = "second",
	},
	packages = {
		first = {
			name = "first",
			source = "modules/first",
			sourceKind = "path",
			installPath = "modules/first",
			dependencies = {
				shared = "shared-first",
			},
		},
		second = {
			name = "second",
			source = "modules/second",
			sourceKind = "path",
			installPath = "modules/second",
			dependencies = {
				shared = "shared-second",
			},
		},
		["shared-first"] = {
			name = "shared",
			source = "packages/shared-first",
			sourceKind = "path",
			installPath = "packages/shared-first",
			dependencies = {},
		},
		["shared-second"] = {
			name = "shared",
			source = "packages/shared-second",
			sourceKind = "path",
			installPath = "packages/shared-second",
			dependencies = {},
		},
	},
}
