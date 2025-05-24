--!strict

local luau = require("@lute/luau")

--- Parses Luau source code into an AstStatBlock
local function parse(source: string): luau.AstStatBlock
	return luau.parse(source).root
end

local function parseexpr(source: string): luau.AstExpr
	return luau.parseexpr(source)
end

export type ParseResult = {
	root: luau.AstStatBlock,
	eof: luau.Eof,
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
