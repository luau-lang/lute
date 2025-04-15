--!strict

local luau = require("@lute/luau")
local T = require("./ast_types")

--- Parses Luau source code into an AstStatBlock
local function parse(source: string): T.AstStatBlock
	return luau.parse(source).root
end

local function parseexpr(source: string): T.AstExpr
	return luau.parseexpr(source)
end

export type ParseResult = {
	root: T.AstStatBlock,
	eof: T.Eof,
}

local function parsefile(source: string): ParseResult
	local result = luau.parse(source)
	return { root = result.root, eof = result.eof }
end

return {
	parse = parse,
	parseexpr = parseexpr,
	parsefile = parsefile,
}
