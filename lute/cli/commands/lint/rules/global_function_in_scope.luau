local lintTypes = require("@lint")
local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local name = "global_function_in_scope"
local message =
	"Non-local function declaration found inside a nested scope. Use 'local function' instead, or move this to the top level."
local target = "https://lute.luau.org/cli/lint/global_function_in_scope.html"

local function lint(
	ast: syntax.AstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}
	local depth = 0

	local visitor: visitorLib.Visitor = visitorLib.create() :: any

	function visitor.visitStatBlock(_: syntax.AstStatBlock)
		depth += 1
		return true
	end

	function visitor.visitStatBlockEnd(_: syntax.AstStatBlock)
		depth -= 1
	end

	function visitor.visitStatFunction(stat: syntax.AstStatFunction)
		-- depth > 1 means we're inside a nested block (not the top-level block)
		if depth > 1 and stat.name.tag ~= "indexname" then
			table.insert(violations, {
				lintname = name,
				location = stat.location,
				message = message,
				severity = "warning" :: "warning", -- LUAUFIX cast needed because severity isn't inferred as a singleton
				sourcepath = sourcepath,
				target = target,
			})
		end
		return true
	end

	visitorLib.visit(ast, visitor)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
