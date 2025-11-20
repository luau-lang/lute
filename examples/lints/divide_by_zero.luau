local lintTypes = require("@commands/lint/types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "divide_by_zero"
local message = "Division by zero detected."

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path): { lintTypes.LintViolation }
	return query
		.findallfromroot(ast, utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "/" or bin.operator.text == "//" or bin.operator.text == "%"
		end)
		:filter(function(bin)
			return bin.rhsoperand.kind == "expr" and bin.rhsoperand.tag == "number" and bin.rhsoperand.value == 0
		end)
		:maptoarray(
			function(
				n: syntax.AstExprBinary
			): lintTypes.LintViolation -- LUAUFIX: Bidiretional inference of generics should let us not need this annotation
				return {
					lintname = name,
					location = n.location,
					message = message,
					severity = "warning",
					sourcepath = sourcepath,
				}
			end
		)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
