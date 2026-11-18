return {
	version = 5,
	dependencies = {
		a = "a@1.0.0",
		b = "b@1.0.0",
	},
	packages = {
		["a@1.0.0"] = {
			name = "a",
			rev = "1.0.0",
			installPath = "Packages/a@1.0.0",
			dependencies = {
				c = "c@1.0.0",
			},
		},
		["b@1.0.0"] = {
			name = "b",
			rev = "1.0.0",
			installPath = "Packages/b@1.0.0",
			dependencies = {
				c = "c@2.0.0",
			},
		},
		["c@1.0.0"] = {
			name = "c",
			rev = "1.0.0",
			installPath = "Packages/c@1.0.0",
			dependencies = {},
		},
		["c@2.0.0"] = {
			name = "c",
			rev = "2.0.0",
			installPath = "Packages/c@2.0.0",
			dependencies = {},
		},
	},
}
