local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local stringext = require("@std/stringext")
local syntax = require("@std/syntax")
local printer = require("@std/syntax/printer")
local utils = require("@std/syntax/utils")

local name = "almost_swapped"
local message = "This looks like a failed attempt to swap."
local target = "https://lute.luau.org/cli/lint/almost_swapped.html"

local compFuncs = {}

function compFuncs.exprLocalsSame(a: syntax.AstExprLocal, b: syntax.AstExprLocal): boolean
	return a["local"] == b["local"]
end

function compFuncs.exprGlobalsSame(a: syntax.AstExprGlobal, b: syntax.AstExprGlobal): boolean
	return a.name.text == b.name.text
end

function compFuncs.exprIndexNamesSame(a: syntax.AstExprIndexName, b: syntax.AstExprIndexName): boolean
	if a.index.text ~= b.index.text then
		return false
	end

	return compFuncs.refExprsSame(a.expression, b.expression)
end

function compFuncs.exprIndexExprsSame(a: syntax.AstExprIndexExpr, b: syntax.AstExprIndexExpr): boolean
	if a.index.tag == "string" and b.index.tag == "string" then
		if a.index.token.text ~= b.index.token.text then
			return false
		else
			return compFuncs.refExprsSame(a.expression, b.expression)
		end
	else
		return compFuncs.refExprsSame(a.expression, b.expression) and compFuncs.refExprsSame(a.index, b.index)
	end
end

function compFuncs.refExprsSame(a: syntax.AstExpr, b: syntax.AstExpr): boolean
	if a.tag ~= b.tag then
		return false
	end

	if a.tag == "local" then
		return compFuncs.exprLocalsSame(a, b :: syntax.AstExprLocal)
	elseif a.tag == "global" then
		return compFuncs.exprGlobalsSame(a, b :: syntax.AstExprGlobal)
	elseif a.tag == "indexname" then
		return compFuncs.exprIndexNamesSame(a, b :: syntax.AstExprIndexName)
	elseif a.tag == "index" then
		return compFuncs.exprIndexExprsSame(a, b :: syntax.AstExprIndexExpr)
	else
		return false
	end
end

-- Report instances of attempted swaps like:
-- a = b; b = a
local function lint(
	ast: syntax.AstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	local violations = {}

	local nodes = query.findallfromroot(ast, utils.isStatBlock).nodes

	for _, block in nodes do
		for i = 1, #block.statements - 1 do
			local currStat = block.statements[i]
			if currStat.tag ~= "assign" or #currStat.values ~= 1 or #currStat.variables ~= 1 then
				continue
			end

			local nextStat = block.statements[i + 1]
			if nextStat.tag ~= "assign" or #nextStat.values ~= 1 or #nextStat.variables ~= 1 then
				continue
			end

			local currVar, currVal = currStat.variables[1].node, currStat.values[1].node
			local nextVar, nextVal = nextStat.variables[1].node, nextStat.values[1].node

			if compFuncs.refExprsSame(currVar, nextVal) and compFuncs.refExprsSame(nextVar, currVal) then
				local currVarStr = stringext.trim(printer.printnode(currVar))
				local currValStr = stringext.trim(printer.printnode(currVal))
				local suggestedFix = `{currVarStr}, {currValStr} = {currValStr}, {currVarStr}`

				table.insert(violations, { -- LUAUFIX: inserted table isn't inferred as a LintViolation
					lintname = name,
					location = syntax.span.create({
						beginline = currStat.location.beginline,
						begincolumn = currStat.location.begincolumn,
						endline = nextStat.location.endline,
						endcolumn = nextStat.location.endcolumn,
					}),
					message = message,
					severity = "warning" :: "warning", -- LUAUFIX: cast needed because severity isn't inferred as a singleton
					sourcepath = sourcepath,
					suggestedfix = {
						fix = suggestedFix,
					},
					target = target,
				})
			end
		end
	end

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
