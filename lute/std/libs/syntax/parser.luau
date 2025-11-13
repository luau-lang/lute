--!strict
-- @std/syntax/parser
-- Parser for Luau source code into Luau AST nodes

local luau = require("@lute/luau")
local types = require("./types")

local parser = {}

--- Parses Luau source code into an AstStatBlock
function parser.parseblock(source: string): types.AstStatBlock
	return luau.parse(source).root
end

function parser.parseexpr(source: string): types.AstExpr
	return luau.parseexpr(source)
end

function parser.parse(source: string): types.ParseResult
	return luau.parse(source)
end

return table.freeze(parser)
