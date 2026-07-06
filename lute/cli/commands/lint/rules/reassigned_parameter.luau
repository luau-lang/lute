local lintTypes = require("@lint")
local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local name = "reassigned_parameter"
local message = "Did you mean to reassign to a function parameter?"
local target = "https://lute.luau.org/cli/lint/reassigned_parameter.html"

type SavedScope = { [syntax.CstLocal]: true }

local function checkAssignment(scopes: { SavedScope }, node: syntax.CstExpr): boolean
	if node.tag ~= "local" then
		return false
	end

	for _, scope in scopes do
		for parameter in scope do
			if node["local"] == parameter then
				return true
			end
		end
	end

	return false
end

local function createViolation(sourcepath: path.Path?, stat: syntax.CstStat): lintTypes.LintViolation
	local violation: lintTypes.LintViolation = {
		lintname = name,
		location = syntax.span.create({
			beginLine = stat.location.beginLine,
			beginColumn = stat.location.beginColumn,
			endLine = stat.location.endLine,
			endColumn = stat.location.endColumn,
		}),
		message = message,
		severity = "warning",
		sourcepath = sourcepath,
		target = target,
	}

	return violation
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	local violations = {}

	local visitor = visitorLib.create()

	local scopes: { SavedScope } = {}

	visitor.visitExprFunction = function(node: syntax.CstExprFunction): boolean
		local scope: SavedScope = {}
		for _, parameter in node.parameters do
			scope[parameter] = true
		end

		table.insert(scopes, scope)

		return true
	end

	visitor.visitStatAssign = function(stat: syntax.CstStatAssign): boolean
		for _, variable in stat.variables do
			if checkAssignment(scopes, variable) then
				table.insert(violations, createViolation(sourcepath, stat))
			end
		end

		return true
	end

	visitor.visitStatCompoundAssign = function(stat: syntax.CstStatCompoundAssign): boolean
		if checkAssignment(scopes, stat.variable) then
			table.insert(violations, createViolation(sourcepath, stat))
		end

		return true
	end

	visitor.visitExprFunctionEnd = function(): ()
		table.remove(scopes)
	end

	visitorLib.visitBlock(cst, visitor)

	return violations
end

local rule: lintTypes.LintRule = table.freeze({
	name = name,
	lint = lint,
})

return rule