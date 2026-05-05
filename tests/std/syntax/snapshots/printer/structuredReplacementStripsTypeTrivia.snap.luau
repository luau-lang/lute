local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("structuredReplacementStripsTypeTrivia", function(ast)
	return query.findAllFromRoot(ast, syntaxUtils.isTypeReference):replace(function(_)
		return syntaxUtils.replacementWithoutTrivia("string")
	end)
end)
