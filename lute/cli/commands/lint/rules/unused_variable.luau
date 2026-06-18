local lintTypes = require("@lint")
local path = require("@std/path")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")
local tableext = require("@std/tableext")
local visitorLib = require("@std/syntax/visitor")

local name = "unused_variable"
local message = "Unused variable detected. Prefix this variable with '_' to indicate that it's intentionally unused."
local target = "https://lute.luau.org/cli/lint/unused_variable.html"

type leaf = { tag: "leaf", vals: { [number]: true } }

type branch = { tag: "branch", entries: { [string]: leaf } }

-- We assume that we only need 2 levels of depth, since there currently no APIs nested more than 2 levels.
-- If we need more levels in the future, we can generalize, but this greatly simplifies the logic.
type smallTrie = { tag: "root", entries: { [string]: branch | leaf } }

local function getWriteOnlyArgs(func: syntax.CstExpr, writeOnlyAPIs: smallTrie): { [number]: true }?
	if func.tag == "global" then
		local entry = writeOnlyAPIs.entries[func.name.text]

		if not entry or entry.tag ~= "leaf" then
			return nil
		end

		return entry.vals
	elseif func.tag == "indexname" and func.expression.tag == "global" then
		local branch = writeOnlyAPIs.entries[(func.expression :: syntax.CstExprGlobal).name.text]

		if not branch or branch.tag ~= "branch" then
			return nil
		end

		local entry = branch.entries[func.index.text]

		return if entry then entry.vals else nil
	elseif func.tag == "index" and func.expression.tag == "global" and func.index.tag == "string" then
		func = func :: syntax.CstExprIndexName | syntax.CstExprIndexExpr
		local branch = writeOnlyAPIs.entries[(func.expression :: syntax.CstExprGlobal).name.text]

		if not branch or branch.tag ~= "branch" then
			return nil
		end

		local entry = branch.entries[(func.index :: syntax.CstExprConstantString).value.text]

		return if entry then entry.vals else nil
	else
		return nil
	end
end

local function unusedLocals(block: syntax.CstStatBlock, writeOnlyAPIs: smallTrie): { syntax.CstLocal }
	local visitor: visitorLib.Visitor & {
		unusedLocals: { syntax.CstLocal },
		scopes: { { [syntax.CstLocal]: boolean } },
		ignoreReferences: { [syntax.CstLocal]: true },
		requiredModules: { [string]: syntax.CstLocal },
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

	local function popAndSaveUnusedLocals(_: syntax.CstNode)
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

	local function markVisited(l: syntax.CstLocal)
		-- Mark local as visited in closest scope
		for i = #visitor.scopes, 1, -1 do
			if visitor.scopes[i][l] ~= nil then
				visitor.scopes[i][l] = true
				return
			end
		end

		error("Local variable not found in any scope")
	end

	function visitor.visitStatBlock(_: syntax.CstStatBlock)
		-- Push a fresh scope
		table.insert(visitor.scopes, {} :: { [syntax.CstLocal]: boolean })
		return true
	end

	visitor.visitStatBlockEnd = popAndSaveUnusedLocals

	function visitor.visitStatLocalDeclaration(stat: syntax.CstStatLocal)
		-- For each (var, value) pair, ignore references to the var in the value
		for i, localVar in stat.variables do
			if stat.values[i] then
				if utils.isRequireCall(stat.values[i]) then
					visitor.requiredModules[localVar.name.text] = localVar
					visitorLib.visitExpression(stat.values[i], visitor)
				else
					visitor.ignoreReferences[localVar] = true
					if localVar.annotation then
						visitorLib.visitType(localVar.annotation, visitor)
					end
					visitorLib.visitExpression(stat.values[i], visitor)
					visitor.ignoreReferences[localVar] = nil
				end
			end
		end

		-- Mark each var as unused in the current scope
		for _, localVar in stat.variables do
			visitor.scopes[#visitor.scopes][localVar] = false
		end

		return false
	end

	function visitor.visitStatFor(stat: syntax.CstStatFor)
		-- Push a scope for the loop variable
		table.insert(visitor.scopes, { [stat.variable] = false })
		return true
	end

	visitor.visitStatForEnd = popAndSaveUnusedLocals

	function visitor.visitStatForIn(stat: syntax.CstStatForIn)
		-- Push a scope for the loop variables
		local newScope: { [syntax.CstLocal]: boolean } = {}
		for _, var in stat.variables do
			newScope[var] = false
		end
		table.insert(visitor.scopes, newScope)
		return true
	end

	visitor.visitStatForInEnd = popAndSaveUnusedLocals

	function visitor.visitStatAssign(stat: syntax.CstStatAssign)
		local i = 1
		local callFound = false
		local prevInLValueContext = visitor.inLValueContext
		while i <= math.min(#stat.variables, #stat.values) do
			local var = stat.variables[i]
			local val = stat.values[i]
			-- An unused local doesn't become used just because it's used to assign to itself, eg:
			-- local x
			-- x = x + 1
			-- However, calls, can assign to multiple variables, so we can't assume variables and values correspond 1-1 once we see a call
			if var.tag == "local" and not callFound then
				visitor.ignoreReferences[var["local"]] = true

				visitorLib.visitExpression(val, visitor)

				visitor.ignoreReferences[var["local"]] = nil
			else
				visitor.inLValueContext = true
				visitorLib.visitExpression(var, visitor)
				visitor.inLValueContext = prevInLValueContext

				visitorLib.visitExpression(val, visitor)
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

	function visitor.visitStatCompoundAssign(stat: syntax.CstStatCompoundAssign)
		-- An unused local doesn't become used just because it's used to assign to itself, eg:
		-- local x
		-- x += x + 1
		if stat.variable.tag == "local" then
			visitor.ignoreReferences[stat.variable["local"]] = true
			visitorLib.visitExpression(stat.value, visitor)
			visitor.ignoreReferences[stat.variable["local"]] = nil
		else
			local prevInLValueContext = visitor.inLValueContext
			visitor.inLValueContext = true
			visitorLib.visitExpression(stat.variable, visitor)
			visitor.inLValueContext = prevInLValueContext

			visitorLib.visitExpression(stat.value, visitor)
		end

		return false
	end

	function visitor.visitStatFunction(stat: syntax.CstStatFunction)
		-- This could be reassigning to a local, in which case we need to apply the same logic as visitStatAssign
		if stat.name.tag == "local" then
			-- If this shadows an unused local in the current scope, we need to mark it as unused
			if visitor.scopes[#visitor.scopes][stat.name["local"]] == false then
				table.insert(visitor.unusedLocals, stat.name["local"])
			end

			visitor.ignoreReferences[stat.name["local"]] = true
			visitorLib.visitExpression(stat.func, visitor)
			visitor.ignoreReferences[stat.name["local"]] = nil
		elseif stat.name.tag == "indexname" and stat.name.accessor.text == ":" then
			local prevMethodContext = visitor.insideMethodContext
			visitor.insideMethodContext = true

			visitorLib.visitExpression(stat.func, visitor)

			visitor.insideMethodContext = prevMethodContext
		elseif stat.name.tag == "index" then
			local prevInLValueContext = visitor.inLValueContext
			visitor.inLValueContext = true
			visitorLib.visitExpression(stat.name, visitor)
			visitor.inLValueContext = prevInLValueContext

			visitorLib.visitExpression(stat.func, visitor)
		else
			visitorLib.visitExpression(stat.func, visitor)
		end

		return false
	end

	function visitor.visitStatLocalFunction(stat: syntax.CstStatLocalFunction)
		-- Recursive functions don't count as references to themselves
		visitor.ignoreReferences[stat.name] = true

		visitorLib.visitExpression(stat.func, visitor)

		visitor.ignoreReferences[stat.name] = nil

		visitor.scopes[#visitor.scopes][stat.name] = false

		return false
	end

	function visitor.visitStatRepeat(stat: syntax.CstStatRepeat)
		-- Push a fresh scope
		table.insert(visitor.scopes, {} :: { [syntax.CstLocal]: boolean })

		-- Manually visit the block's states so we can keep the scope around
		for _, bodyStat in stat.body.statements do
			visitorLib.visitStatement(bodyStat, visitor)
		end

		-- Visit the condition with the same scope as the body
		visitorLib.visitExpression(stat.condition, visitor)

		popAndSaveUnusedLocals(stat)

		return false
	end

	function visitor.visitExprLocal(node: syntax.CstExprLocal)
		if node.token.text == "self" and visitor.insideMethodContext then
			return false
		end

		local cstlocal = node["local"]

		-- We only ignore writes to locals in the same scope
		-- We don't want to warn writes to upvalues as unused
		if visitor.inLValueContext and visitor.scopes[#visitor.scopes][cstlocal] ~= nil then
			return false
		end

		if visitor.ignoreReferences[cstlocal] then
			return false
		end

		markVisited(cstlocal)

		return false
	end

	function visitor.visitExprFunction(node: syntax.CstExprFunction)
		-- Push a scope for the function parameters
		local newScope: { [syntax.CstLocal]: boolean } = {}

		for _, param in node.parameters do
			newScope[param] = false
		end

		table.insert(visitor.scopes, newScope)

		return true
	end

	visitor.visitExprFunctionEnd = popAndSaveUnusedLocals

	function visitor.visitTypeReference(node: syntax.CstTypeReference)
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

	function visitor.visitExprIndexExpr(node: syntax.CstExprIndexExpr)
		visitorLib.visitExpression(node.expression, visitor)

		local prevInLValueContext = visitor.inLValueContext
		visitor.inLValueContext = false
		visitorLib.visitExpression(node.index, visitor)
		visitor.inLValueContext = prevInLValueContext

		return false
	end

	function visitor.visitExprCall(node: syntax.CstExprCall)
		local writeOnlyIndices = getWriteOnlyArgs(node.func, writeOnlyAPIs)

		if not writeOnlyIndices then
			return true
		end

		visitorLib.visitExpression(node.func, visitor)

		for i, arg in node.arguments do
			if writeOnlyIndices[i] then
				local prevInLValueContext = visitor.inLValueContext
				visitor.inLValueContext = true
				visitorLib.visitExpression(arg, visitor)
				visitor.inLValueContext = prevInLValueContext
			else
				visitorLib.visitExpression(arg, visitor)
			end
		end

		return false
	end

	visitorLib.visitBlock(block, visitor)

	return visitor.unusedLocals
end

local function isPositiveInt(v: unknown): boolean
	return type(v) == "number" and v > 0 and math.floor(v) == v
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	-- Validate context.options, which should be of form { ["api"] = { number } },
	-- where the number keys represent argument indices which only write to their passed values.
	for api, args in context.options do
		local errorMessage =
			`Expected options for API '{api}' to be an array of argument indices which only write to their passed values`
		if type(args) ~= "table" then
			error(errorMessage)
		end

		for k, v in args do
			if not isPositiveInt(k) or not isPositiveInt(v) then
				error(errorMessage)
			end
		end
	end

	local writeOnlyAPIs: smallTrie = {
		tag = "root",
		entries = {
			table = { tag = "branch", entries = { insert = { tag = "leaf", vals = { [1] = true } } } },
		},
	}

	for k, v in context.options do
		local parts = k:split(".")
		if #parts < 1 or #parts > 2 then
			error(`Invalid API '{k}' in options. Only APIs up to 2 levels deep are supported.`)
		end

		if #parts == 1 then
			local entry = writeOnlyAPIs.entries[parts[1]]

			if entry then
				error(
					`API '{parts[1]}' is already defined as {if entry.tag == "branch" then "part of " else ""}a write-only API, so '{k}' cannot be added as a write-only API.`
				)
			end

			writeOnlyAPIs.entries[parts[1]] = { tag = "leaf", vals = tableext.toSet(v :: { number }) } -- We validate v above, so the cast is ok
		else
			if not writeOnlyAPIs.entries[parts[1]] then
				writeOnlyAPIs.entries[parts[1]] = {
					tag = "branch",
					entries = { [parts[2]] = { tag = "leaf", vals = tableext.toSet(v :: { number }) } },
				}
			else
				local branch = writeOnlyAPIs.entries[parts[1]]
				if branch.tag ~= "branch" then
					error(
						`API '{parts[1]}' is already defined as a write-only API, so '{k}' cannot be added as a write-only API.`
					)
				end
				branch.entries[parts[2]] = { tag = "leaf", vals = tableext.toSet(v :: { number }) } -- We validate v above, so the cast is ok
			end
		end
	end

	return tableext.map(unusedLocals(cst, writeOnlyAPIs), function(l: syntax.CstLocal): lintTypes.LintViolation
		return {
			lintname = name,
			location = l.location, -- LUAUFIX: Bidirectional inference should let us know that l : syntax.CstLocal
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
			target = target,
			tags = { "unnecessary" },
		}
	end)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
