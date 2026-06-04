local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntax_utils = require("@std/syntax/utils")

return {
	options = {
		{ kind = "string", name = "functionName", default = "math.isnan" },
	},
	transform = function(ctx)
		local functionName = ctx.options.functionName
		return query
			.findAllFromRoot(ctx.parseresult.root, syntax_utils.isExprBinary)
			:filter(function(bin)
				return bin.operator.text == "~="
					and bin.lhsOperand.tag == "local"
					and bin.rhsOperand.tag == "local"
					and bin.lhsOperand.token.text == bin.rhsOperand.token.text
			end)
			:replace(function(bin)
				return `{functionName}({(bin.lhsOperand :: syntax.CstExprLocal).token.text})`
			end)
	end,
}
