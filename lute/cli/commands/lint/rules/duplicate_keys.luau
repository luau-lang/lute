local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "duplicate_keys"
local message = "Duplicate keys detected in table literal."
local target = "https://lute.luau.org/cli/lint/duplicate_keys.html"

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	_context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	local function makeViolation(location: syntax.Span): lintTypes.LintViolation
		return {
			lintname = name,
			location = location,
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
			target = target,
		}
	end

	return query
		.findAllFromRoot(cst, utils.isExprTable)
		:flatMap(function(tableExpr: syntax.CstExprTable): { lintTypes.LintViolation }
			local violations = {}

			local seenKeys: { [string | number]: true } = {}
			local numArrayElems = 0

			for _, entry in tableExpr.entries do
				if entry.kind == "list" then
					numArrayElems += 1
					if seenKeys[numArrayElems] then
						table.insert(violations, makeViolation(entry.location))
					end
				elseif entry.kind == "record" then
					if seenKeys[entry.key.text] then
						table.insert(violations, makeViolation(entry.location))
					end
					seenKeys[entry.key.text] = true
				elseif entry.kind == "general" then
					if entry.key.tag == "string" then
						if seenKeys[entry.key.value.text] then
							table.insert(violations, makeViolation(entry.location))
						end
						seenKeys[entry.key.value.text] = true
					elseif entry.key.tag == "number" then
						if seenKeys[entry.key.value] then
							table.insert(violations, makeViolation(entry.location))
						elseif numArrayElems > 0 and entry.key.value <= numArrayElems then
							table.insert(violations, makeViolation(entry.location))
						end
						seenKeys[entry.key.value] = true
					end
				end
			end

			return violations
		end).nodes
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
