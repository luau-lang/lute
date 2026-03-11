local query = require("../query")
local types = require("../types")

local retrieverLib = {}

function retrieverLib.leftmosttrivia(n: types.AstNode): { types.Trivia }
	local q = query.findallfromroot<<types.Token>>(n, function(n: types.AstNode)
		return if n.kind == "token" then n else nil
	end)

	local leftmostToken: types.Token? = nil

	for _, token in q.nodes do
		if leftmostToken == nil then
			leftmostToken = token
		elseif token.location.beginline < leftmostToken.location.beginline then
			leftmostToken = token
		elseif
			token.location.beginline == leftmostToken.location.beginline
			and token.location.begincolumn < leftmostToken.location.begincolumn
		then
			leftmostToken = token
		end
	end

	return if leftmostToken ~= nil then leftmostToken.leadingtrivia else {}
end

function retrieverLib.rightmosttrivia(n: types.AstNode): { types.Trivia }
	local q = query.findallfromroot<<types.Token>>(n, function(n: types.AstNode)
		return if n.kind == "token" then n else nil
	end)

	local rightmostToken: types.Token? = nil

	for _, token in q.nodes do
		if rightmostToken == nil then
			rightmostToken = token
		elseif token.location.beginline > rightmostToken.location.beginline then
			rightmostToken = token
		elseif
			token.location.beginline == rightmostToken.location.beginline
			and token.location.begincolumn > rightmostToken.location.begincolumn
		then
			rightmostToken = token
		end
	end

	return if rightmostToken ~= nil then rightmostToken.trailingtrivia else {}
end

return table.freeze(retrieverLib)
