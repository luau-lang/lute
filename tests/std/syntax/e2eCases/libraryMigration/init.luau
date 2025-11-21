local types = require("@std/syntax/types")
local utils = require("@std/syntax/utils")
local qUtils = require("./utils")
local query = require("@std/syntax/query")
local tableext = require("@std/tableext")
local getRequireStatements = qUtils.getRequireStatements
local transformLibraryAccess = qUtils.transformLibraryAccess

local functionMap = {
	["oldFunction"] = "newFunction",
	["anotherFunction"] = "anotherNewFunction",
}

local function transformRequires(block: types.AstStatBlock): (string, types.replacements)
	local oldLibRequires = getRequireStatements(block, "old")

	local requireArgRepl = query
		.findallfromroot(oldLibRequires.nodes[1] :: any, utils.isExprCall)
		:map(function(node)
			return node.arguments[1].node.index
		end)
		:replace(function(node)
			return "new"
		end)

	local oldLibVar = oldLibRequires.nodes[1].variables[1].node
	local oldLibAlias = ""
	local requiredVarAliasRepl = query
		.findallfromroot(oldLibVar :: any, utils.isToken)
		:replace(function(node: types.Token)
			oldLibAlias = node.text
			return "newLibrary"
		end)
	return oldLibAlias, tableext.combine(requireArgRepl, requiredVarAliasRepl)
end

local function transform(ctx): types.replacements
	local parseresult = ctx.parseresult
	local block = parseresult.root
	local oldLibAlias, requireRepl = transformRequires(block)
	local libAccessRepl = transformLibraryAccess(block, oldLibAlias, function(_, index)
		local oldFunction = index.text
		return `newLibrary.{functionMap[oldFunction]}`
	end)
	return tableext.combine(requireRepl, libAccessRepl)
end

return transform
