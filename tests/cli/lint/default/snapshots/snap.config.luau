return {
	default = {
		args = {
			"lint",
			"-c",
			"tests/cli/lint/default/snapshots/lint.config.luau",
		},
		-- lint exits with code 1 when warnings are found; use expectedExitCode = 0 for no-warning cases
		expectedExitCode = 1,
	},
	overrides = {
		["reference_variable_marked_used_in_lvalue_context"] = {
			expectedExitCode = 0,
		},
		["reference_variable_marked_used_in_lvalue_even_via_parens"] = {
			expectedExitCode = 0,
		},
		["reference_variable_updated_marked_used"] = {
			expectedExitCode = 0,
		},
	},
}
