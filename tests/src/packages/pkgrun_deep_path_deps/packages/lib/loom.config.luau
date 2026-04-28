return {
	package = {
		name = "lib",
		version = "0.0.0",
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
