local lintTypes = require("../types")
local path = require("@std/path")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")
local visitorLib = require("@std/syntax/visitor")

local name = "unused_variable"
local message = "Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused."
local target = "https://lute.luau.org/cli/lint/unused_variable.html"

local function isRequireCall(expr: syntax.AstExpr)
	return expr.tag == "call" and expr.func.tag == "global" and expr.func.name.text == "require"
end

local function unusedLocals(block: syntax.AstStatBlock): { syntax.AstLocal }
	local visitor: visitorLib.Visitor & {
		unusedLocals: { syntax.AstLocal },
		scopes: { { [syntax.AstLocal]: boolean } },
		ignoreReferences: { [syntax.AstLocal]: true },
		requiredModules: { [string]: syntax.AstLocal },
		insideMethodContext: boolean,
		inLValueContext: boolean,
	} =
		visitorLib.create() :: any
	visitor.unusedLocals = {}
	visitor.scopes = {}
	visitor.ignoreReferences = {}
	visitor.requiredModules = {}
	-- Used to avoid lookups to `self`
	visitor.insideMethodContext = false
	visitor.inLValueContext = false

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
		local i = 1
		local callFound = false
		local prevInLValueContext = visitor.inLValueContext
		while i <= math.min(#stat.variables, #stat.values) do
			local var = stat.variables[i].node
			local val = stat.values[i].node
			-- An unused local doesn't become used just because it's used to assign to itself, eg:
			-- local x
			-- x = x + 1
			-- However, calls, can assign to multiple variables, so we can't assume variables and values correspond 1-1 once we see a call
			if var.tag == "local" and not callFound then
				visitor.ignoreReferences[var["local"]] = true

				visitorLib.visitexpression(val, visitor)

				visitor.ignoreReferences[var["local"]] = nil
			else
				visitor.inLValueContext = true
				visitorLib.visitexpression(var, visitor)
				visitor.inLValueContext = prevInLValueContext

				visitorLib.visitexpression(val, visitor)
			end

			if val.tag == "call" then
				callFound = true
			end

			i = i + 1
		end

		-- If we see a call, we no longer know if variables correspond 1-1 with values, since functions can return multiple values
		-- In this case, we stop caring about ignoring references, and only check as many values as there are variables

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
			local prevInLValueContext = visitor.inLValueContext
			visitor.inLValueContext = true
			visitorLib.visitexpression(stat.variable, visitor)
			visitor.inLValueContext = prevInLValueContext

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
		elseif stat.name.tag == "indexname" and stat.name.accessor.text == ":" then
			local prevMethodContext = visitor.insideMethodContext
			visitor.insideMethodContext = true

			visitorLib.visitexpression(stat.func, visitor)

			visitor.insideMethodContext = prevMethodContext
		elseif stat.name.tag == "index" then
			local prevInLValueContext = visitor.inLValueContext
			visitor.inLValueContext = true
			visitorLib.visitexpression(stat.name, visitor)
			visitor.inLValueContext = prevInLValueContext

			visitorLib.visitexpression(stat.func, visitor)
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

	function visitor.visitStatRepeat(stat: syntax.AstStatRepeat)
		-- Push a fresh scope
		table.insert(visitor.scopes, {} :: { [syntax.AstLocal]: boolean })

		-- Manually visit the block's states so we can keep the scope around
		for _, bodyStat in stat.body.statements do
			visitorLib.visitstatement(bodyStat, visitor)
		end

		-- Visit the condition with the same scope as the body
		visitorLib.visitexpression(stat.condition, visitor)

		popAndSaveUnusedLocals(stat)

		return false
	end

	function visitor.visitExprLocal(node: syntax.AstExprLocal)
		if node.token.text == "self" and visitor.insideMethodContext then
			return false
		end

		local astlocal = node["local"]

		-- We only ignore writes to locals in the same scope
		-- We don't want to warn writes to upvalues as unused
		if visitor.inLValueContext and visitor.scopes[#visitor.scopes][astlocal] ~= nil then
			return false
		end

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

	function visitor.visitExprIndexExpr(node: syntax.AstExprIndexExpr)
		visitorLib.visitexpression(node.expression, visitor)

		local prevInLValueContext = visitor.inLValueContext
		visitor.inLValueContext = false
		visitorLib.visitexpression(node.index, visitor)
		visitor.inLValueContext = prevInLValueContext

		return false
	end

	visitorLib.visitblock(block, visitor)

	return visitor.unusedLocals
end

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path?): { lintTypes.LintViolation }
	return tableext.map(unusedLocals(ast), function(l): lintTypes.LintViolation
		return table.freeze({
			lintname = name,
			location = l.location,
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
			target = target,
			tags = { "unnecessary" },
		}) -- LUAUFIX: Table literal doesn't subtype against lintTypes.LintViolation for some reason
	end)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
