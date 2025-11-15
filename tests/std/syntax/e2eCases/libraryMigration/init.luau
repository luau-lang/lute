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
local qUtils = require("./utils")
local getRequireStatements = qUtils.getRequireStatements
local transformLibraryAccess = qUtils.transformLibraryAccess

-- local newFunction = newLibrary.newFunction
-- local oldFunction = oldLibrary.oldFunction
local function transformLocal() -- need to transform newFunction use
end

-- maps oldLibrary function names to newLibrary functions
local functionMap = {
	["oldFunction"] = "newFunction",
	["anotherFunction"] = "anotherNewFunction",
}

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

local function transform(block: luau.AstStatBlock): string
	local t = t.new()
	local oldLibAlias = transformRequires(t, block)
	transformLibraryAccess(t, block, oldLibAlias, function(_, index)
		local oldFunction = index.text
		return `newLibrary.{functionMap[oldFunction]}`
	end)
	return printer.printnode(block :: any, t.replacements)
end

return {
	transform = transform,
	cases = cases,
}

-- having parent nodes will be goated! context in the tree is huge
