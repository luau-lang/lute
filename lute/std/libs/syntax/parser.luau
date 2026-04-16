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

--- Parses `source` as a single Luau expression and returns the resulting `AstExpr`.
function parser.parseExpr(source: string): types.AstExpr
	return luau.parseExpr(source)
end

--- Parses `source` as a complete Luau file and returns the full `ParseResult`, including the root block and EOF token.
function parser.parse(source: string): types.ParseResult
	return luau.parse(source)
end

return table.freeze(parser)
