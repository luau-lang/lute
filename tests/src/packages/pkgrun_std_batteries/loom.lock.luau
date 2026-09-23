return {
	version = 3,
	dependencies = {
		dep = "dep@v1.0.0",
	},
	packages = {
		["dep@v1.0.0"] = {
			name = "dep",
			rev = "v1.0.0",
			source = "owner/dep",
			sourceKind = "github",
			installPath = "Packages/dep",
			dependencies = {},
		},
	},
}
