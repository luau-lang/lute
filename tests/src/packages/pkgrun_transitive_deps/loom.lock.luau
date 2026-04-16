return {
	version = 2,
	packages = { "dep@v1.2.3" },
	dependencies = {
		["dep@v1.2.3"] = {
			name = "dep",
			rev = "v1.2.3",
			source = "owner/dep",
			sourceKind = "github",
			installPath = "Packages/dep@v1.2.3",
			dependencies = {
				internaldepAlias = "internaldep@v4.5.6",
			},
		},
		["internaldep@v4.5.6"] = {
			name = "internaldep",
			rev = "v4.5.6",
			source = "owner/internaldep",
			sourceKind = "github",
			installPath = "Packages/internaldep@v4.5.6",
			dependencies = {},
		},
	},
}
