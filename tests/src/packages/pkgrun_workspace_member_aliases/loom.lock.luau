return {
	version = 4,
	dependencies = {
		first = {
			shared = "shared-first",
		},
		second = {
			shared = "shared-second",
		},
	},
	packages = {
		["shared-first"] = {
			name = "shared",
			source = "shared-first",
			sourceKind = "path",
			installPath = "packages/shared-first",
			dependencies = {},
		},
		["shared-second"] = {
			name = "shared",
			source = "shared-second",
			sourceKind = "path",
			installPath = "packages/shared-second",
			dependencies = {},
		},
	},
}
