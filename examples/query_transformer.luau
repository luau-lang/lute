local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntax_utils = require("@std/syntax/utils")

local transformTypes = require("@transform")

local function transform(ctx: transformTypes.Context)
	return query
		.findAllFromRoot(ctx.parseresult :: syntax.ParseResult, syntax_utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "~="
				and bin.lhsOperand.tag == "local"
				and bin.rhsOperand.tag == "local"
				and bin.lhsOperand.token.text == bin.rhsOperand.token.text
		end)
		:replace(function(bin)
			return `math.isnan({(bin.lhsOperand :: syntax.CstExprLocal).token.text})`
		end)
end

return transform
