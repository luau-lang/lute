return {
	luau = {
		languagemode = "strict",
		lint = { ["*"] = true },
		linterrors = true,
		aliases = {
			commands = "./lute/cli/commands",
			lute = "./definitions",
			std = "./lute/std/libs",
		},
	},
	lute = {
		lint = {
			ignores = { "**/*.d.luau", "**/*.snap.luau" },
		},
		format = {
			ignores = {
				"**/*.d.luau",
				"**/generated-types.luau",
				"**/*unformatted*.luau",
				"tests/parserExamples/**",
			},
		},
	},
}
