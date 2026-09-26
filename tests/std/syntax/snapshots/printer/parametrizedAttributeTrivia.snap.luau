local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("parametrizedAttributeTrivia", function(cst)
	return query.findAllFromRoot(cst, syntaxUtils.isAttributeParametrized):replace(function()
		return "replaced"
	end)
end)
