local path = require("@std/path")
local syntax = require("@std/syntax")

export type severity = "error" | "warning" | "info" | "hint"
export type tag = "unnecessary" | "deprecated"
export type fix = {
	location: syntax.Span,
	replacement: string,
}

export type LintViolation = {
	lintname: string,
	location: syntax.Span,
	message: string,
	severity: severity,
	sourcepath: path.Path?,
	suggestedfix: {
		read location: syntax.Span?, -- if nil, applies to whole violation location
		read fix: string,
	}?,
	target: string?, -- Additional information on the violation (e.g link to docs)
	tags: { tag }?,
}

export type GlobalsConfig = { [string]: unknown }
export type RuleOptions = { [string]: unknown }

export type RuleContext = {
	globals: GlobalsConfig,
	options: RuleOptions,
}

export type LintRule = {
	read lint: (ast: syntax.AstStatBlock, sourcepath: path.Path?, context: RuleContext) -> { LintViolation },
	read name: string,
}

return {}
