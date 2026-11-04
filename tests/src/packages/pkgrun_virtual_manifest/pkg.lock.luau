return {
	version = 5,
	dependencies = {
		first = "first",
	},
	devDependencies = {
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
			devDependencies = {
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
