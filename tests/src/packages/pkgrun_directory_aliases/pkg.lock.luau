return {
	version = 5,
	dependencies = {
		withinit = "withinit",
		noinit = "noinit",
		srconly = "srconly",
		escapes = "escapes",
	},
	devDependencies = {},
	packages = {
		withinit = { name = "withinit", sourceKind = "path", source = "packages/withinit", installPath = "packages/withinit", dependencies = {} },
		noinit = { name = "noinit", sourceKind = "path", source = "packages/noinit", installPath = "packages/noinit", dependencies = {} },
		srconly = { name = "srconly", sourceKind = "path", source = "packages/srconly", installPath = "packages/srconly", dependencies = {} },
		escapes = { name = "escapes", sourceKind = "path", source = "packages/escapes", installPath = "packages/escapes", dependencies = {} },
	},
}
