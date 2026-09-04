local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local util = require("./util")

util.printReplacement("attributeListTrivia", function(cst)
	return query.findAllFromRoot(cst, syntaxUtils.isAttributeList):replace(function()
		return "replaced"
	end)
end)
