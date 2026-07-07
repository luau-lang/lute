local types = require("@lint")
local parseIgnores = require("../lib/parseIgnores")
local path = require("@std/path")
local syntax = require("@std/syntax")

export type RuleConfig = {
	ignores: { string }?,
	severity: types.severity?,
	off: true?,
	options: types.RuleOptions?,
}

export type LintConfigData = {
	ignores: { string }?, -- globs/paths to ignore as we walk lintee files
	globals: types.GlobalsConfig?, -- globals to pass down to all rules via context
	rulepaths: { path.Pathlike }?, -- paths to local rules to use
	ruleconfigs: {
		[string]: RuleConfig?,
	}?,
}

export type LintConfigOverride = {
	paths: { string },
} & LintConfigData

export type LintConfigOverrides = { LintConfigOverride }

export type ResolvedFileConfig = RuleConfigData & {
	ignoreData: parseIgnores.GitignoreData?,
	rules: { types.LintRule },
}

export type ResolvedOverride = RuleConfigData & {
	ignoreData: parseIgnores.GitignoreData?,
	paths: { parseIgnores.Glob },
	rules: { types.LintRule },
}

export type LintConfig = LintConfigData & { overrides: LintConfigOverrides? }

export type RuleConfigurations = { [string]: RuleConfig }

export type RuleIgnores = { [string]: parseIgnores.GitignoreData }

export type RuleConfigData = {
	globals: types.GlobalsConfig,
	ruleConfigs: RuleConfigurations,
	ruleIgnores: RuleIgnores,
}

export type GlobalRuleConfigData = RuleConfigData & {
	overrides: { ResolvedOverride },
}

export type fix = {
	location: syntax.Span,
	replacement: string,
}

return {}
