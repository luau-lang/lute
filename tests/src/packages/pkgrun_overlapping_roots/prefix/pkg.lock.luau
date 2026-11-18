return {
	version = 5,
	dependencies = {
		foo = "foo",
		foobar = "foobar",
		app = "app",
		application = "application",
	},
	packages = {
		foo = {
			name = "foo",
			installPath = "packages/foo",
			dependencies = { shared = "foo-shared" },
		},
		foobar = {
			name = "foobar",
			installPath = "packages/foobar",
			dependencies = { shared = "foobar-shared" },
		},
		app = {
			name = "app",
			installPath = "packages/app",
			dependencies = { shared = "app-shared" },
		},
		application = {
			name = "application",
			installPath = "packages/application",
			dependencies = { shared = "application-shared" },
		},
		["foo-shared"] = { name = "foo-shared", installPath = "packages/foo-shared", dependencies = {} },
		["foobar-shared"] = { name = "foobar-shared", installPath = "packages/foobar-shared", dependencies = {} },
		["app-shared"] = { name = "app-shared", installPath = "packages/app-shared", dependencies = {} },
		["application-shared"] = {
			name = "application-shared",
			installPath = "packages/application-shared",
			dependencies = {},
		},
	},
}
