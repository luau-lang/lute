local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "divide_by_zero"
local message = "Division by zero detected."
local target = "https://lute.luau.org/cli/lint/divide_by_zero.html"

local function isZeroLiteral(expr: syntax.AstExpr): boolean
	return expr.kind == "expr" and expr.tag == "number" and expr.value == 0
end

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path?): { lintTypes.LintViolation }
	return query
		.findallfromroot(ast, utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "/" or bin.operator.text == "//" or bin.operator.text == "%"
		end)
		:filter(function(bin)
			return isZeroLiteral(bin.rhsoperand)
		end)
		:maptoarray(
			function(
				n: syntax.AstExprBinary
			): lintTypes.LintViolation? -- LUAUFIX: Bidirectional inference of generics should let us not need this annotation
				local suggestedfix = nil
				if n.operator.text == "/" or n.operator.text == "//" then
					if isZeroLiteral(n.lhsoperand) then
						return nil
					elseif n.lhsoperand.tag == "unary" and n.lhsoperand.operator.text == "-" then
						if isZeroLiteral(n.lhsoperand.operand) then
							suggestedfix = table.freeze({ fix = "0 / 0" })
						else
							suggestedfix = table.freeze({ fix = "-math.huge" })
						end
					else
						suggestedfix = table.freeze({ fix = "math.huge" })
					end
				elseif n.operator.text == "%" then
					suggestedfix = table.freeze({ fix = "0 / 0" })
				end

				return {
					lintname = name,
					location = n.location,
					message = message,
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = suggestedfix,
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
