local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntax_utils = require("@std/syntax/utils")

local function transform(ctx)
	return query
		.findallfromroot(ctx.parseresult.root, syntax_utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "~="
				and bin.lhsOperand.tag == "local"
				and bin.rhsOperand.tag == "local"
				and bin.lhsOperand.token.text == bin.rhsOperand.token.text
		end)
		:replace(function(bin)
			return `math.isnan({(bin.lhsOperand :: syntax.AstExprLocal).token.text})`
		end)
end

return transform
