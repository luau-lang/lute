local syntax = require("@std/syntax")
local path = require("@std/path")
local visitorLib = require("@std/syntax/visitor")
local lintTypes = require("../types")

local name = "reassigned_parameter"
local message = "Reassigning parameters is likely a mistake."
local target = "https://lute.luau.org/cli/lint/reassigned_parameter.html"

local function checkAssignment(parameters: { syntax.CstLocal }, node: syntax.CstExpr): boolean
	if node.tag ~= "local" then
		return false
	end

	for _, parameter in parameters do
		if node["local"] == parameter then
			return true
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
	Cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	local violations = {}

	local visitor = visitorLib.create()

	-- We could store parameters by scope here, which would make scope cleanup easier,
	-- however, that comes at the cost of it being harder to check assigments
	-- (we would then need to loop over every scope)
	local parameters: { syntax.CstLocal } = {}

	visitor.visitExprFunction = function(node: syntax.CstExprFunction): boolean
		for _, parameter in node.parameters do
			table.insert(parameters, parameter.node)
		end

		return true
	end

	visitor.visitStatAssign = function(stat: syntax.CstStatAssign): boolean
		for _, variable in stat.variables do
			if checkAssignment(parameters, variable.node) then
				table.insert(violations, createViolation(sourcepath, stat))
			end
		end

		return true
	end

	visitor.visitStatCompoundAssign = function(stat: syntax.CstStatCompoundAssign): boolean
		if checkAssignment(parameters, stat.variable) then
			table.insert(violations, createViolation(sourcepath, stat))
		end

		return true
	end

	visitor.visitExprFunctionEnd = function(node: syntax.CstExprFunction): ()
		for _, parameter in node.parameters do
			local index = table.find(parameters, parameter.node)
			if index then
				table.remove(parameters, index)
			end
		end
	end

	visitorLib.visitBlock(Cst, visitor)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return rule
