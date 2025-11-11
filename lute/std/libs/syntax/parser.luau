--!strict
-- @std/syntax/parser
-- Parser for Luau source code into Luau AST nodes

local luau = require("@lute/luau")

local parser = {}

--- Parses Luau source code into an AstStatBlock
function parser.parse(source: string): luau.AstStatBlock
	return luau.parse(source).root
end

function parser.parseexpr(source: string): luau.AstExpr
	return luau.parseexpr(source)
end

export type ParseResult = {
	root: luau.AstStatBlock,
	eof: luau.Eof,
}

function parser.parsefile(source: string): ParseResult
	local result = luau.parse(source)
	return { root = result.root, eof = result.eof }
end

return table.freeze(parser)
