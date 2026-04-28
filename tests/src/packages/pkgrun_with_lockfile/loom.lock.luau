return {
	version = 3,
	dependencies = {
		dep = "dep@v1.2.3",
	},
	packages = {
		["dep@v1.2.3"] = {
			name = "dep",
			rev = "v1.2.3",
			source = "owner/dep",
			sourceKind = "github",
			installPath = "Packages/dep",
			dependencies = {
				internaldepAlias = "internaldep@v4.5.6",
			},
		},
		["internaldep@v4.5.6"] = {
			name = "internaldep",
			rev = "v4.5.6",
			source = "owner/internaldep",
			sourceKind = "github",
			installPath = "Packages/internaldep",
			dependencies = {},
		},
	},
}
