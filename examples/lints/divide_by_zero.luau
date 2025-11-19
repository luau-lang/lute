local lintTypes = require("@commands/lint/types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "divide_by_zero"
local message = "Division by zero detected."

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path): { lintTypes.LintViolation }
	local violations = {}

	query
		.findallfromroot(ast, utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "/" or bin.operator.text == "//" or bin.operator.text == "%"
		end)
		:filter(function(bin)
			return utils.isExprConstantNumber(bin.rhsoperand) ~= nil
				and (bin.rhsoperand :: syntax.AstExprConstantNumber).value == 0
		end)
		:foreach(function(n: syntax.AstExprBinary)
			table.insert(violations, { -- LUAUFIX: severity isn't inferred as a singleton, so table.insert is mad
				lintname = name,
				location = n.location,
				message = message,
				severity = "warning",
				sourcepath = sourcepath,
			})
		end)

	return violations
end

return {
	name = name,
	lint = lint,
} :: lintTypes.LintRule
