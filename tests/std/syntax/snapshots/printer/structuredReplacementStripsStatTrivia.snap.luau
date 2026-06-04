local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("structuredReplacementStripsStatTrivia", function(cst)
	return query.findAllFromRoot(cst, syntaxUtils.isStatLocal):replace(function(_)
		return syntaxUtils.replacementWithoutTrivia("local y = 2")
	end)
end)
