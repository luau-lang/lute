local luau = require("@std/luau")
local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax_utils = require("@std/syntax/utils")

local function transform(ctx)
	local parsedResult = parser.parsefile(ctx.source)

	local q = query.select(parsedResult.root, syntax_utils.isExprBinary)

	local replacements = q:filter(function(bin)
		return bin.operator.text == "~="
			and bin.lhsoperand.tag == "local"
			and bin.rhsoperand.tag == "local"
			and bin.lhsoperand.token.text == bin.rhsoperand.token.text
	end):replace(function(bin)
		return `math.isnan({(bin.lhsoperand :: luau.AstExprLocal).token.text})`
	end)

	return printer.printfile(parsedResult, replacements)
end

return transform
