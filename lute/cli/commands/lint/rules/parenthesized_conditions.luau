local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxPrinter = require("@std/syntax/printer")

local name = "parenthesized_conditions"
local message = "Luau doesn't require parentheses around conditions. You can remove them for readability."
local target = "https://lute.luau.org/cli/lint/parenthesized_conditions.html"

local function lint(ast: syntax.AstStatBlock, sourcepath: path.path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}

	query
		.findallfromroot(ast, function(node: syntax.AstNode): (syntax.AstExprIfElse | syntax.AstStatIf)?
			if (node.kind == "expr" or node.kind == "stat") and node.tag == "conditional" then
				return node
			end
			return nil
		end)
		:foreach(function(ifStat)
			if ifStat.condition.tag == "group" then
				table.insert(violations, {
					lintname = name,
					location = ifStat.condition.location,
					message = message,
					severity = "info",
					sourcepath = sourcepath,
					suggestedfix = {
						fix = syntaxPrinter.printnode(ifStat.condition.expression),
					},
					target = target,
				})
			end

			for _, elseIfStat in ifStat.elseifs do
				if elseIfStat.condition.tag == "group" then
					table.insert(violations, {
						lintname = name,
						location = elseIfStat.condition.location,
						message = message,
						severity = "info",
						sourcepath = sourcepath,
						suggestedfix = {
							fix = syntaxPrinter.printnode(elseIfStat.condition.expression),
						},
						target = target,
					})
				end
			end
		end)

	query
		.findallfromroot(ast, function(node: syntax.AstNode): (syntax.AstStatWhile | syntax.AstStatRepeat)?
			if node.kind == "stat" and (node.tag == "while" or node.tag == "repeat") then
				return node
			end
			return nil
		end)
		:filter(function(n)
			return n.condition.tag == "group"
		end)
		:foreach(function(n)
			table.insert(violations, {
				lintname = name,
				location = n.condition.location,
				message = message,
				severity = "info",
				sourcepath = sourcepath,
				suggestedfix = {
					fix = syntaxPrinter.printnode((n.condition :: syntax.AstExprGroup).expression),
				},
				target = target,
			})
		end)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
