--!strict
-- @std/syntax/parser
-- Parser for Luau source code into Luau AST nodes

local luau = require("@lute/luau")

local types = require("./types")

local parser = {}

--- Parses Luau source code into an AstStatBlock
function parser.parseBlock(source: string): types.AstStatBlock
	return luau.parse(source).root
end

function parser.parseExpr(source: string): types.AstExpr
	return luau.parseExpr(source)
end

function parser.parse(source: string): types.ParseResult
	return luau.parse(source)
end

return table.freeze(parser)
