return {
	default = {
		args = { "lint", "--no-default-lints", "-r", "lute/cli/commands/lint/rules/duplicate_keys.luau" },
		-- lint exits with code 1 when warnings are found; use expectedExitCode = 0 for no-warning cases
		expectedExitCode = 1,
	},
	overrides = {
		["duplicate_keys_no_warn_general_zero"] = {
			expectedExitCode = 0,
		},
		["output_flag_to_file"] = {
			args = {
				"lint",
				"--no-default-lints",
				"-r",
				"lute/cli/commands/lint/rules/divide_by_zero.luau",
				"-o",
				"/tmp/lute_snap_output_flag_test.txt",
			},
		},
	},
}
