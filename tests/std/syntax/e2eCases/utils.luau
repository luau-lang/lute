local luau = require("@lute/luau")
local query = require("@std/syntax/query")
local t = require("@std/syntax/transform")
local utils = require("@std/syntax/utils")
local printer = require("@std/syntax/printer")
local cases = require("./libraryMigration/cases")

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

local function transformLibraryAccess(
	t: t.transform,
	block: luau.AstStatBlock,
	libAlias: string,
	repl: (expr: luau.AstExpr, index: luau.Token) -> string
)
	t:selectFromRoot(block :: any, utils.isExprIndexName)
		:filter(function(node: luau.AstExprIndexName)
			-- get root expression; determine if it's oldLib
			return #query
					.selectFromRoot(node.expression :: any, utils.isBaseToken)
					:filter(function(node: luau.Token)
						return node.text == libAlias
					end).nodes > 0
		end)
		:replace(function(node)
			return repl(node.expression, node.index)
		end)
end

return {
	getRequireStatements = getRequireStatements,
	transformLibraryAccess = transformLibraryAccess,
}
