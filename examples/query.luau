local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local cst = syntax.parseExpr("require(OldComponent)")

local p = query.findAllFromRoot(cst, utils.isRequireCall):filter(function(call)
	local firstArg = call.arguments[1]
	return firstArg.tag == "indexname" and firstArg.index.text == "OldComponent"
end)

local argIndexNames = query.map(p, function(call: syntax.CstExprCall)
	return call.arguments[1]
end)

local _replacements = argIndexNames:replace(function(_)
	return "NewComponent"
end)
