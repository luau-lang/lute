local query = require("../query")
local types = require("../types")

local retrieverLib = {}

--- Returns the leading trivia of the leftmost token in `n`, or an empty array if there are no tokens.
function retrieverLib.leftmostTrivia(n: types.CstNode): { types.Trivia }
	local q = query.findAllFromRoot<<types.CstToken>>(
		n :: any,
		function(n: types.CstNode) -- LUAUFIX: Code too complex emitted because CstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local leftmostToken: types.CstToken? = nil

	for _, token in q.nodes do
		if leftmostToken == nil then
			leftmostToken = token
		elseif token.location.beginLine < leftmostToken.location.beginLine then
			leftmostToken = token
		elseif
			token.location.beginLine == leftmostToken.location.beginLine
			and token.location.beginColumn < leftmostToken.location.beginColumn
		then
			leftmostToken = token
		end
	end

	return if leftmostToken ~= nil then leftmostToken.leadingTrivia else {}
end

--- Returns the trailing trivia of the rightmost token in `n`, or an empty array if there are no tokens.
function retrieverLib.rightmostTrivia(n: types.CstNode): { types.Trivia }
	local q = query.findAllFromRoot(
		n :: any,
		function(n: types.CstNode) -- LUAUFIX: Code too complex emitted because CstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local rightmostToken: types.CstToken? = nil

	for _, token in q.nodes do
		if rightmostToken == nil then
			rightmostToken = token
		elseif token.location.beginLine > rightmostToken.location.beginLine then
			rightmostToken = token
		elseif
			token.location.beginLine == rightmostToken.location.beginLine
			and token.location.beginColumn > rightmostToken.location.beginColumn
		then
			rightmostToken = token
		end
	end

	return if rightmostToken ~= nil then rightmostToken.trailingTrivia else {}
end

return table.freeze(retrieverLib)
