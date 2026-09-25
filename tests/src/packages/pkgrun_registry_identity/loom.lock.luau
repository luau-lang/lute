return {
	version = 4,
	dependencies = {
		packageentry = {
			app = "app",
			myCitrus = "citrus--registry-root@1.0.0",
		},
	},
	packages = {
		["app"] = {
			name = "app",
			source = "packages/app",
			sourceKind = "path",
			installPath = "packages/app",
			dependencies = {
				citrus = "citrus--registry-path@1.0.0",
			},
		},
		["citrus--registry-root@1.0.0"] = {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			registry = "https://root-registry.example.com",
			installPath = "packages/citrus-root",
			dependencies = {},
		},
		["citrus--registry-path@1.0.0"] = {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			registry = "https://path-registry.example.com",
			installPath = "packages/citrus-path",
			dependencies = {},
		},
	},
}
