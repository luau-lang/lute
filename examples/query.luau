local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local ast = syntax.parseExpr("require(OldComponent)")

local p = query.findallfromroot(ast, utils.isRequireCall):filter(function(call)
	local firstArg = call.arguments[1].node
	return firstArg.tag == "indexname" and firstArg.index.text == "OldComponent"
end)

-- Can we improve the type solver here so we don't need to add this annotation?
local argIndexNames = query.map(p, function(call: syntax.AstExprCall)
	return call.arguments[1].node :: syntax.AstExprIndexName
end)

local _replacements = argIndexNames:replace(function(_)
	return "NewComponent"
end)
