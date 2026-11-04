return {
	package = {
		name = "lib",
		version = "0.0.0",
		content_root = "src",
		dependencies = {
			utils = {
				name = "shared",
				sourceKind = "path",
				source = "../shared",
			},
			h = {
				name = "helpers",
				sourceKind = "path",
				source = "../helpers",
			},
		},
	},
}
