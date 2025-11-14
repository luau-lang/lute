--[[
this module implements a function migration transform:
empirical use-case is migrating from an old library to new library
we need to update:
    library import
    function import
    function usage

]]

local luau = require("@lute/luau")
local query = require("@std/syntax/query")
local t = require("@std/syntax/transform")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")
local cases = require("./libraryMigration/cases")

-- local newFunction = newLibrary.newFunction
-- local oldFunction = oldLibrary.oldFunction
local function transformLocal() -- need to transform newFunction use
	
end

-- maps oldLibrary function names to newLibrary functions
local functionMap = {
	["oldFunction"] = "newFunction",
	["anotherFunction"] = "anotherNewFunction",
}

-- assumes roblox requires structure
local function getRequireStatements(block: luau.AstStatBlock, requiredModule: string?): query.query<luau.AstStatLocal>
	local requires = query.selectFromRoot(block :: any, utils.isStatLocal):filter(function(node: luau.AstStatLocal)
		local callValue = utils.isExprCall(node.values[1].node :: any)
		local callIsRequire = callValue
			and callValue.func.tag == "global"
			and (callValue.func :: luau.AstExprGlobal).name.text == "require"
		return if callIsRequire then true else false
	end)
	if requiredModule then
		return requires:filter(function(node)
			local requireCall = node.values[1].node :: luau.AstExprCall
			local requireArg = utils.isExprIndexName(requireCall.arguments[1].node :: any)
			return if requireArg then requireArg.index.text == requiredModule else false
		end)
	end
	return requires
end

local function transformRequires(q: t.transform, block: luau.AstStatBlock): string
	local oldLibRequires = getRequireStatements(block, "old")

	q:selectFromRoot(oldLibRequires.nodes[1] :: any, utils.isExprCall)
		:map(function(node)
			return node.arguments[1].node.index
		end)
		:replace(function(node)
			return "new"
		end)

	-- change this step to get the local var in the statement
	local oldLibVar = oldLibRequires.nodes[1].variables[1].node
	local oldLibAlias
	q:selectFromRoot(oldLibVar :: any, utils.isToken):replace(function(node: luau.Token)
		oldLibAlias = node.text
		return "newLibrary"
	end)
	return oldLibAlias
end

local function transformOldLibraryAccess(t: t.transform, block: luau.AstStatBlock, oldLibAlias: string)
	t:selectFromRoot(block :: any, utils.isExprIndexName)
		:filter(function(node: luau.AstExprIndexName)
			-- get root expression; determine if it's oldLib
			return #query.selectFromRoot(node :: any, utils.isBaseToken):filter(function(node: luau.Token)
				return node.text == oldLibAlias
			end).nodes > 0
		end)
		:replace(function(node)
			local oldFunction = node.index.text
			return `newLibrary.{functionMap[oldFunction]}`
		end)
end

local function transform(block: luau.AstStatBlock): string
	local t = t.new(block :: any)
	local oldLibAlias = transformRequires(t, block)
	transformOldLibraryAccess(t, block, oldLibAlias)
	return printer.printnode(block :: any, t.replacements)
end

return {
	transform = transform,
	cases = cases,
}

-- having parent nodes will be goated! context in the tree is huge
