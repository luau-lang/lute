local luau = require("@lute/luau")
local t = require("@std/syntax/transform")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")
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
		local arg = node.arguments[1].node
		t.replacements[arg :: any] = `table.unpack({printer.printnode(arg :: any)})`
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
	local transform = t.new(block :: any)
	qUtils.transformLibraryAccess(transform, block, "sameLibrary", function(expr, index: luau.Token)
		return `{printer.printnode(expr :: any)}.{apiMap[index.text]}`
	end)
	transformCallArgs(transform, block)
	return transform:transform()
end

return {
	transform = transform,
	cases = require("./apiSurfaceChange/cases"),
}
