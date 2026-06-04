local query = require("@std/syntax/query")
local syntaxTypes = require("@std/syntax/types")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("mixedReplacements", function(cst)
	local replacements: syntaxTypes.Replacements = {}
	local bools = query.findAllFromRoot(cst, syntaxUtils.isExprConstantBool)
	local i = 0
	bools:forEach(function(node)
		i += 1
		if i == 1 then
			replacements[node] = "replaced_a"
		else
			replacements[node] = syntaxUtils.replacementWithoutTrivia("replaced_b")
		end
	end)
	return replacements
end)
