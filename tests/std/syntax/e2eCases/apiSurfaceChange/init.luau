local luau = require("@lute/luau")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")
local qUtils = require("./utils")
local tableext = require("@std/tableext")
local query = require("@std/syntax/query")

local apiMap = {
	numFunc = "processNumber",
	stringFunc = "handleText",
	arrayFunc = "processArray",
	processData = "handleData",
	getCount = "retrieveCount",
}

local argReplacements = {
	arrayFunc = function(arg: luau.AstExpr)
		return `table.unpack({printer.printnode(arg :: any)})`
	end,
}

local function transformCallArgs(block: luau.AstStatBlock)
	local argNodeToFuncName = {} :: { [luau.AstNode]: string }
	return query
		.findallfromroot(block, utils.isExprCall)
		:filter(function(node: luau.AstExprCall)
			return node.func.index and argReplacements[node.func.index.text] ~= nil
		end)
		:map(function(node: luau.AstExprCall)
			local arg = node.arguments[1].node
			argNodeToFuncName[arg] = (node.func :: luau.AstExprIndexName).index.text
			return arg
		end)
		:replace(function(node: luau.AstExpr)
			return (argReplacements[argNodeToFuncName[node]] :: (luau.AstExpr) -> string)(node)
		end)
end

local function transform(ctx)
	local parseresult = ctx.parseresult
	local block = parseresult.root
	local libAccessReplacements = qUtils.transformLibraryAccess(block, "sameLibrary", function(expr, index: luau.Token)
		return `{printer.printnode(expr)}.{apiMap[index.text]}`
	end)
	local argReplacements = transformCallArgs(block)
	return tableext.combine(libAccessReplacements, argReplacements)
end

return transform
