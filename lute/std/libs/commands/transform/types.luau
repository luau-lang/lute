local mutablecst = require("@lute/syntax/mutablecst")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")

export type Context<Options = { [any]: any }> = {
	path: string,
	source: string,
	parseresult: syntax.CstParseResult,
	options: Options,
}

--- Context passed to migrations when `lute transform` is run with `--mutable-cst`
export type MutableContext<Options = { [any]: any }> = {
	path: string,
	source: string,
	parseresult: mutablecst.CstParseResult,
	options: Options,
}

export type Transformer = (Context) -> string | syntaxTypes.Replacements

export type ConfigOption =
	{
		kind: "string",
		name: string,
		default: string?,
	}
	| {
		kind: "boolean",
		name: string,
		default: boolean?,
	}

export type InitializationContext<Options = { [any]: any }> = {
	options: Options,
}

export type Migration = {
	options: { ConfigOption }?,
	initialize: ((InitializationContext) -> ())?,
	transform: Transformer,
}

return {
	DELETION_MARKER = "$DELETION_MARKER",
}
