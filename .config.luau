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
			ignores = {
				"**/*.d.luau",
				"**/*.snap.luau",
				"tests/cli/format/stylua/**",
			},
		},
		format = {
			ignores = {
				"**/*.d.luau",
				"**/generated-types.luau",
				"**/*unformatted*.luau",
				"tests/cli/format/stylua/**",
				"tests/parserExamples/**",
				"tests/src/debug/compile_error.luau",
			},
		},
	},
}
