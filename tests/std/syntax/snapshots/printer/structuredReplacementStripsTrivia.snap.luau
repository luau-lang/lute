local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("structuredReplacementStripsTrivia", function(cst)
	return query.findAllFromRoot(cst, syntaxUtils.isExprConstantBool):replace(function(_)
		return { content = "replaced", preserveTrivia = false }
	end)
end)
