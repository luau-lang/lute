return {
	default = {
		-- Every case runs in `--check` mode so a snapshot run can never rewrite its own input.
		-- stylua keeps these inputs at one trailing newline, which is all the placeholder
		-- formatter normalises, so they are reported as already formatted.
		args = { "format", "--check", "--verbose" },
		expectedExitCode = 0,
	},
	overrides = {
		-- `--help` exits before reading any file, so the appended input path is ignored.
		["help"] = {
			args = { "format", "--help" },
		},
	},
}
