local luau = require("@lute/luau")
local t = require("@std/syntax/transform")
local utils = require("@std/syntax/utils")
local qUtils = require("./utils")
local getRequireStatements = qUtils.getRequireStatements
local transformLibraryAccess = qUtils.transformLibraryAccess

local functionMap = {
	["oldFunction"] = "newFunction",
	["anotherFunction"] = "anotherNewFunction",
}

local function transformRequires(q: t.transform, block: luau.AstStatBlock): string?
	local oldLibRequires = getRequireStatements(block, "old")

	q:findallfromroot(oldLibRequires.nodes[1] :: any, utils.isExprCall)
		:map(function(node)
			return node.arguments[1].node.index
		end)
		:replace(function(node)
			return "new"
		end)

	local oldLibVar = oldLibRequires.nodes[1].variables[1].node
	local oldLibAlias
	q:findallfromroot(oldLibVar :: any, utils.isToken):replace(function(node: luau.Token)
		oldLibAlias = node.text
		return "newLibrary"
	end)
	return oldLibAlias
end

local function transform(ctx): string
	local parseresult = ctx.parseresult
	local transform = t.new(parseresult :: any)
	local block = parseresult.root
	local oldLibAlias = transformRequires(transform, block)
	transformLibraryAccess(transform, block, oldLibAlias, function(_, index)
		local oldFunction = index.text
		return `newLibrary.{functionMap[oldFunction]}`
	end)
	return transform:transform()
end

return transform
