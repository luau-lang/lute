return {
	package = {
		name = "app",
		version = "0.0.0",
		content_root = "src",
		dependencies = {
			lib = {
				sourceKind = "path",
				source = "../lib",
			},
			shared = {
				sourceKind = "path",
				source = "../shared",
			},
		},
	},
}
