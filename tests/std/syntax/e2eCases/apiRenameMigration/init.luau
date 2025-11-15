local luau = require("@lute/luau")
local query = require("@std/syntax/query")
local t = require("@std/syntax/transform")
local utils = require("@std/syntax/utils")
local tableext = require("@std/tableext")
local printer = require("@std/syntax/printer")
local cases = require("./libraryMigration/cases")
local qUtils = require("./utils")

local apiMap = {
	numFunc = "processNumber",
	stringFunc = "handleText",
	arrayFunc = "processArray",
	processData = "handleData",
	getCount = "retrieveCount",
}

local argReplacements = {
	arrayFunc = function(t: t.transform, node: luau.AstExprCall)
		t:selectFromRoot(node :: any, utils.isExprTable)
			:map(function(tbl: luau.AstExprTable)
				return tbl.closebrace
			end)
			:replace(function()
				return ""
			end)
		t:selectFromRoot(node :: any, utils.isExprTable)
			:map(function(tbl: luau.AstExprTable)
				return tbl.openbrace
			end)
			:replace(function()
				return ""
			end)
	end,
}

local function transformCallArgs(t: t.transform, block: luau.AstStatBlock)
	t:selectFromRoot(block, utils.isExprCall)
		:filter(function(node)
			return node.func.index and argReplacements[node.func.index.text] ~= nil
		end)
		:replace(function(node)
			return node.func.index and argReplacements[node.func.index.text](t, node)
		end)
end

local function transform(block: luau.AstStatBlock): string
	local transform = t.new()
	qUtils.transformOldLibraryAccess(transform, block, "sameLibrary", function(expr, index: luau.Token)
		return `{printer.printnode(expr :: any)}.{apiMap[index.text]}`
	end)
	transformCallArgs(transform, block)
	return printer.printnode(block :: any, transform.replacements)
end

return {
	transform = transform,
	cases = require("./apiRenameMigration/cases"),
}
