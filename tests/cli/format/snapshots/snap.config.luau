return {
	default = {
		-- Every case runs in `--check` mode so a snapshot run can never rewrite its own input.
		args = { "format", "--check", "--verbose" },
		expectedExitCode = 0,
	},
	overrides = {
		-- `--help` exits before reading any file, so the appended input path is ignored.
		["help"] = {
			args = { "format", "--help" },
		},
		-- Deliberately unformatted, so `--check` reports it and exits 1. `unformatted` in the name is
		-- what keeps stylua off it; see `.styluaignore`.
		["check_unformatted_file"] = {
			expectedExitCode = 1,
		},
	},
}
