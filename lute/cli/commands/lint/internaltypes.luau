local types = require("./types")
local parseIgnores = require("../lib/parseIgnores")
local path = require("@std/path")

export type RuleConfig = {
	ignores: { string }?,
	severity: types.severity?,
	off: true?,
	options: types.RuleOptions?,
}

export type LintConfig = {
	ignores: { path.pathlike }?, -- globs/paths to ignore as we walk lintee files
	globals: types.GlobalsConfig?, -- globals to pass down to all rules via context
	rulepaths: { path.pathlike }?, -- paths to local rules to use
	ruleconfigs: {
		[string]: RuleConfig?,
	}?,
}

export type RuleConfigurations = { [string]: RuleConfig }

export type RuleIgnores = { [string]: parseIgnores.GitignoreData }

export type RuleConfigData = {
	globals: types.GlobalsConfig,
	ruleConfigs: RuleConfigurations,
	ruleIgnores: RuleIgnores,
}

return {}
