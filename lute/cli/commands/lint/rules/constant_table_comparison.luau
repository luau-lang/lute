local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local stringext = require("@std/stringext")
local syntax = require("@std/syntax")
local syntaxPrinter = require("@std/syntax/printer")
local utils = require("@std/syntax/utils")

local name = "constant_table_comparison"
local message =
	"Constant table comparison detected. Comparing a table reference to a table literal will always evaluate to false."
local target = "https://lute.luau.org/cli/lint/constant_table_comparison.html"

local function isTableLiteral(expr: syntax.CstExpr): boolean
	return expr.tag == "table"
		or (expr.tag == "group" and isTableLiteral(expr.expression))
		or (expr.tag == "cast" and isTableLiteral(expr.operand))
end

local function isEmptyTableLiteral(expr: syntax.CstExpr): boolean
	if expr.tag == "table" then
		return #expr.entries == 0
	elseif expr.tag == "group" then
		return isEmptyTableLiteral(expr.expression)
	elseif expr.tag == "cast" then
		return isEmptyTableLiteral(expr.operand)
	else
		return false
	end
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "==" or bin.operator.text == "~="
		end)
		:filter(function(bin)
			return isTableLiteral(bin.rhsOperand) or isTableLiteral(bin.lhsOperand)
		end)
		:mapToArray(
			function(
				bin: syntax.CstExprBinary
			): lintTypes.LintViolation -- LUAUFIX: Bidirectional inference of generics should let us not need this annotation
				local suggestedFix: string? = nil

				if isEmptyTableLiteral(bin.lhsOperand) then
					suggestedFix =
						`next({stringext.trim(syntaxPrinter.printNode(bin.rhsOperand))}) {bin.operator.text} nil`
				elseif isEmptyTableLiteral(bin.rhsOperand) then
					suggestedFix =
						`next({stringext.trim(syntaxPrinter.printNode(bin.lhsOperand))}) {bin.operator.text} nil`
				end

				return {
					lintname = name,
					location = bin.location,
					message = message,
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = if suggestedFix ~= nil
						then {
							fix = suggestedFix,
						}
						else nil,
					target = target,
				}
			end
		)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
