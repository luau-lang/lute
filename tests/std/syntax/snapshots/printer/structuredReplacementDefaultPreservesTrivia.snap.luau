local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("structuredReplacementDefaultPreservesTrivia", function(ast)
	return query.findAllFromRoot(ast, syntaxUtils.isExprConstantBool):replace(function(_)
		return { content = "replaced" }
	end)
end)
