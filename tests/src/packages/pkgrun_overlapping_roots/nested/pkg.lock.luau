return {
	version = 5,
	dependencies = {
		app = "app",
		child = "child",
		application = "application",
	},
	packages = {
		app = {
			name = "app",
			installPath = "packages/app",
			dependencies = { shared = "app-shared" },
		},
		child = {
			name = "child",
			installPath = "packages/app/vendor/child",
			dependencies = { shared = "child-shared" },
		},
		application = {
			name = "application",
			installPath = "packages/app/vendor/application",
			dependencies = { shared = "application-shared" },
		},
		["app-shared"] = {
			name = "app-shared",
			installPath = "packages/app-shared",
			dependencies = {},
		},
		["child-shared"] = {
			name = "child-shared",
			installPath = "packages/child-shared",
			dependencies = {},
		},
		["application-shared"] = {
			name = "application-shared",
			installPath = "packages/application-shared",
			dependencies = {},
		},
	},
}
