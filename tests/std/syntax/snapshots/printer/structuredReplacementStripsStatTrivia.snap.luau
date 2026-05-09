local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("structuredReplacementStripsStatTrivia", function(ast)
	return query.findAllFromRoot(ast, syntaxUtils.isStatLocal):replace(function(_)
		return syntaxUtils.replacementWithoutTrivia("local y = 2")
	end)
end)
