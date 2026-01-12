local syntax = require("@std/syntax")
local path = require("@std/path")

export type severity = "error" | "warning" | "info" | "hint"
export type tag = "unnecessary" | "deprecated"

export type LintViolation = {
	read lintname: string,
	read location: syntax.span,
	read message: string,
	read severity: severity,
	read sourcepath: path.path?,
	read tags: { tag }?,
} -- TODO: add suggested fix

export type LintRule = {
	read lint: (ast: syntax.AstStatBlock, sourcepath: path.path?) -> { LintViolation },
	read name: string,
}

return {}
