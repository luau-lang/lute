local luau = require("@std/luau")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local ast = luau.parseexpr("require(OldComponent)")

local p = query
	.select(ast, utils.isExprCall)
	:filter(function(call)
		local calledFunc = call.func
		return calledFunc.tag == "global" and calledFunc.name.text == "require"
	end)
	:filter(function(call)
		local firstArg = call.arguments[1].node
		return firstArg.tag == "indexname" and firstArg.index.text == "OldComponent"
	end)

-- Can we improve the type solver here so we don't need to add this annotation?
local argIndexNames = query.map(p, function(call: luau.AstExprCall)
	return call.arguments[1].node :: luau.AstExprIndexName
end)

local replacements = argIndexNames:replace(function(node)
	return "NewComponent"
end)
