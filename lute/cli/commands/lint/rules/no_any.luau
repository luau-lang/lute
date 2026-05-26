local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "no_any"
local message =
	"Explicit 'any' type detected. Use 'unknown' for type-safe alternatives that require narrowing before use."
local target = "https://lute.luau.org/cli/lint/no_any.html"

local function lint(
	ast: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	return query
		.findAllFromRoot(ast, utils.isTypeReference)
		:filter(function(typeRef)
			return typeRef.name.text == "any" and typeRef.prefix == nil
		end)
		:mapToArray(function(n: syntax.CstTypeReference): lintTypes.LintViolation?
			return {
				lintname = name,
				location = n.location,
				message = message,
				severity = "warning",
				sourcepath = sourcepath,
				suggestedfix = table.freeze({ fix = "unknown" }),
				target = target,
			}
		end)
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
