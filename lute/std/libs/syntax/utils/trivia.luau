local query = require("../query")
local types = require("../types")

local retrieverLib = {}

function retrieverLib.leftmosttrivia(n: types.AstNode): { types.Trivia }
	local q = query.findallfromroot<<types.Token>>(
		n :: any,
		function(n: types.AstNode) -- LUAUFIX: Code too complex emitted because AstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local leftmostToken: types.Token? = nil

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

	return if leftmostToken ~= nil then leftmostToken.leadingtrivia else {}
end

function retrieverLib.rightmosttrivia(n: types.AstNode): { types.Trivia }
	local q = query.findallfromroot(
		n :: any,
		function(n: types.AstNode) -- LUAUFIX: Code too complex emitted because AstNode is very large
			return if n.kind == "token" then n else nil
		end
	)

	local rightmostToken: types.Token? = nil

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

	return if rightmostToken ~= nil then rightmostToken.trailingtrivia else {}
end

return table.freeze(retrieverLib)
