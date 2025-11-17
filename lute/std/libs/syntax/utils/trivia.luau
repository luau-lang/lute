local query = require("../query")
local types = require("../types")

local retrieverLib = {}

function retrieverLib.leftmosttrivia(n: types.AstNode): { types.Trivia }
	local q: query.query<types.Token> = query.findallfromroot(n, function(n)
		return if n.istoken ~= nil and n.istoken then n else nil
	end)

	local leftmostToken: types.Token? = nil

	for _, token in q.nodes do
		if leftmostToken == nil then
			leftmostToken = token
		elseif token.position.line < leftmostToken.position.line then
			leftmostToken = token
		elseif
			token.position.line == leftmostToken.position.line
			and token.position.column < leftmostToken.position.column
		then
			leftmostToken = token
		end
	end

	return if leftmostToken ~= nil then leftmostToken.leadingtrivia else {}
end

function retrieverLib.rightmosttrivia(n: types.AstNode): { types.Trivia }
	local q: query.query<types.Token> = query.findallfromroot(n, function(n)
		return if n.istoken ~= nil and n.istoken then n else nil
	end)

	local rightmostToken: types.Token? = nil

	for _, token in q.nodes do
		if rightmostToken == nil then
			rightmostToken = token
		elseif token.position.line > rightmostToken.position.line then
			rightmostToken = token
		elseif
			token.position.line == rightmostToken.position.line
			and token.position.column > rightmostToken.position.column
		then
			rightmostToken = token
		end
	end

	return if rightmostToken ~= nil then rightmostToken.trailingtrivia else {}
end

return table.freeze(retrieverLib)
