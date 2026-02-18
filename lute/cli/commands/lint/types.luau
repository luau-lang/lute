local syntax = require("@std/syntax")
local parseIgnores = require("../lib/parseIgnores")
local path = require("@std/path")

export type severity = "error" | "warning" | "info" | "hint"
export type tag = "unnecessary" | "deprecated"

export type LintViolation = {
	lintname: string,
	location: syntax.span,
	message: string,
	severity: severity,
	sourcepath: path.path?,
	suggestedfix: {
		read location: syntax.span?, -- if nil, applies to whole violation location
		read fix: string,
	}?,
	target: string?, -- Additional information on the violation (e.g link to docs)
	tags: { tag }?,
}

export type LintRule = {
	read lint: (ast: syntax.AstStatBlock, sourcepath: path.path?, context: RuleContext) -> { LintViolation },
	read name: string,
}

export type RuleConfig = {
	ignores: { string }?,
	severity: severity?,
	off: true?,
	options: RuleOptions?,
}

export type GlobalsConfig = { [string]: unknown }
export type RuleOptions = { [string]: unknown }

export type LintConfig = {
	ignores: { path.pathlike }?, -- globs/paths to ignore as we walk lintee files
	globals: GlobalsConfig?, -- globals to pass down to all rules via context
	rules: {
		paths: { path.pathlike }?, -- paths to local rules to use
		[string]: RuleConfig?,
	}?,
}

export type RuleContext = {
	globals: GlobalsConfig,
	options: RuleOptions,
}

export type RuleConfigurations = { [string]: RuleConfig }

export type RuleIgnores = { [string]: parseIgnores.GitignoreData }

export type RuleConfigData = {
	globals: GlobalsConfig,
	ruleConfigs: RuleConfigurations,
	ruleIgnores: RuleIgnores,
}

return {}
