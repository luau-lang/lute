local syntax = require("@std/syntax")
local path = require("@std/path")

export type severity = "error" | "warning" | "info" | "hint"

export type LintViolation = {
	lintname: string,
	location: syntax.span,
	message: string,
	severity: severity,
	sourcepath: path.path,
} -- TODO: add suggested fix

export type LintRule = {
	lint: (ast: syntax.AstStatBlock, sourcepath: path.path) -> { LintViolation },
	name: string,
}

return {}
