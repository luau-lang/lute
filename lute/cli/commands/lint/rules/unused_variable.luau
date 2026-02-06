local lintTypes = require("../types")
local path = require("@std/path")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local visitorLib = require("@std/syntax/visitor")

local name = "unused_variable"
local message = "Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused."

local function isRequireCall(expr: syntax.AstExpr)
	return expr.tag == "call" and expr.func.tag == "global" and expr.func.name.text == "require"
end

local function unusedLocals(block: syntax.AstStatBlock): { syntax.AstLocal }
	local visitor: visitorLib.Visitor & {
		unusedLocals: { syntax.AstLocal },
		scopes: { { [syntax.AstLocal]: boolean } },
		ignoreReferences: { [syntax.AstLocal]: boolean },
		requiredModules: { [string]: syntax.AstLocal },
	} =
		visitorLib.create() :: any
	visitor.unusedLocals = {}
	visitor.scopes = {}
	visitor.ignoreReferences = {}
	visitor.requiredModules = {}

	local function popAndSaveUnusedLocals(_: syntax.AstNode)
		-- Pop scope and save unused locals
		local scope = table.remove(visitor.scopes)
		if not scope then
			error("Expected a scope to pop")
		end

		for l, visited in scope do
			if not visited and l.name.text:sub(1, 1) ~= "_" then
				table.insert(visitor.unusedLocals, l)
			end
		end
	end

	local function markVisited(l: syntax.AstLocal)
		-- Mark local as visited in closest scope
		for i = #visitor.scopes, 1, -1 do
			if visitor.scopes[i][l] ~= nil then
				visitor.scopes[i][l] = true
				return
			end
		end

		error("Local variable not found in any scope")
	end

	function visitor.visitStatBlock(_: syntax.AstStatBlock)
		-- Push a fresh scope
		table.insert(visitor.scopes, {} :: { [syntax.AstLocal]: boolean })
		return true
	end

	visitor.visitStatBlockEnd = popAndSaveUnusedLocals

	function visitor.visitStatLocalDeclaration(stat: syntax.AstStatLocal)
		-- For each (var, value) pair, ignore references to the var in the value
		for i, localVar in stat.variables do
			if stat.values[i] then
				if isRequireCall(stat.values[i].node) then
					visitor.requiredModules[localVar.node.name.text] = localVar.node
				else
					visitor.ignoreReferences[localVar.node] = true
					if localVar.node.annotation then
						visitorLib.visittype(localVar.node.annotation, visitor)
					end
					visitorLib.visitexpression(stat.values[i].node, visitor)
					visitor.ignoreReferences[localVar.node] = nil
				end
			end
		end

		-- Mark each var as unused in the current scope
		for _, localVar in stat.variables do
			visitor.scopes[#visitor.scopes][localVar.node] = false
		end

		return false
	end

	function visitor.visitStatFor(stat: syntax.AstStatFor)
		-- Push a scope for the loop variable
		table.insert(visitor.scopes, { [stat.variable] = false })
		return true
	end

	visitor.visitStatForEnd = popAndSaveUnusedLocals

	function visitor.visitStatForIn(stat: syntax.AstStatForIn)
		-- Push a scope for the loop variables
		local newScope: { [syntax.AstLocal]: boolean } = {}
		for _, var in stat.variables do
			newScope[var.node] = false
		end
		table.insert(visitor.scopes, newScope)
		return true
	end

	visitor.visitStatForInEnd = popAndSaveUnusedLocals

	function visitor.visitStatAssign(stat: syntax.AstStatAssign)
		for i, var in stat.variables do
			-- An unused local doesn't become used just because it's used to assign to itself, eg:
			-- local x
			-- x = x + 1
			if var.node.tag == "local" then
				visitor.ignoreReferences[var.node["local"]] = true

				visitorLib.visitexpression(stat.values[i].node, visitor)

				visitor.ignoreReferences[var.node["local"]] = nil
			else
				visitorLib.visitexpression(var.node, visitor)
				visitorLib.visitexpression(stat.values[i].node, visitor)
			end
		end

		return false
	end

	function visitor.visitStatCompoundAssign(stat: syntax.AstStatCompoundAssign)
		-- An unused local doesn't become used just because it's used to assign to itself, eg:
		-- local x
		-- x += x + 1
		if stat.variable.tag == "local" then
			visitor.ignoreReferences[stat.variable["local"]] = true
			visitorLib.visitexpression(stat.value, visitor)
			visitor.ignoreReferences[stat.variable["local"]] = nil
		else
			visitorLib.visitexpression(stat.value, visitor)
		end

		return false
	end

	function visitor.visitStatFunction(stat: syntax.AstStatFunction)
		-- This could be reassigning to a local, in which case we need to apply the same logic as visitStatAssign
		if stat.name.tag == "local" then
			-- If this shadows an unused local in the current scope, we need to mark it as unused
			if visitor.scopes[#visitor.scopes][stat.name["local"]] == false then
				table.insert(visitor.unusedLocals, stat.name["local"])
			end

			visitor.ignoreReferences[stat.name["local"]] = true
			visitorLib.visitexpression(stat.func, visitor)
			visitor.ignoreReferences[stat.name["local"]] = nil
		else
			visitorLib.visitexpression(stat.func, visitor)
		end

		return false
	end

	function visitor.visitStatLocalFunction(stat: syntax.AstStatLocalFunction)
		-- Recursive functions don't count as references to themselves
		visitor.ignoreReferences[stat.name] = true

		visitorLib.visitexpression(stat.func, visitor)

		visitor.ignoreReferences[stat.name] = nil

		visitor.scopes[#visitor.scopes][stat.name] = false

		return false
	end

	function visitor.visitExprLocal(node: syntax.AstExprLocal)
		local astlocal = node["local"]

		if visitor.ignoreReferences[astlocal] then
			return false
		end

		markVisited(astlocal)

		return false
	end

	function visitor.visitExprFunction(node: syntax.AstExprFunction)
		-- Push a scope for the function parameters
		local newScope: { [syntax.AstLocal]: boolean } = {}

		for _, param in node.parameters do
			newScope[param.node] = false
		end

		table.insert(visitor.scopes, newScope)

		return true
	end

	visitor.visitExprFunctionEnd = popAndSaveUnusedLocals

	function visitor.visitTypeReference(node: syntax.AstTypeReference)
		if not node.prefix then
			return true
		end

		local requiredModule = visitor.requiredModules[node.prefix.text]

		if not requiredModule then
			return true
		end

		markVisited(requiredModule)

		return true
	end

	visitorLib.visitblock(block, visitor)

	return visitor.unusedLocals
end

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path?): { lintTypes.LintViolation }
	return tableext.map(unusedLocals(ast), function(l)
		return table.freeze({
			lintname = name,
			location = l.location,
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
		}) :: lintTypes.LintViolation
	end)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
