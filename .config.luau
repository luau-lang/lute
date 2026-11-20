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
			ignores = { "**/*.d.luau", "**/*.snap.luau", "tests/src/debug/*.luau" },
		},
		format = {
			ignores = {
				"**/*.d.luau",
				"**/generated-types.luau",
				"definitions/syntax/mutablecst.luau",
				"**/*unformatted*.luau",
				"tests/parserExamples/**",
				"tests/src/debug/*.luau",
			},
		},
	},
}
