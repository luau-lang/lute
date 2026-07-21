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
			ignores = { "**/*.snap.luau" },
		},
	},
}
