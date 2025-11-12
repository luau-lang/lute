local luau = require("@std/luau")
local query = require("@std/syntax/query")
local syntax_utils = require("@std/syntax/utils")

local function transform(ctx)
	return query
		.selectFromRoot(ctx.parseresult.root, syntax_utils.isExprBinary)
		:filter(function(bin)
			return bin.operator.text == "~="
				and bin.lhsoperand.tag == "local"
				and bin.rhsoperand.tag == "local"
				and bin.lhsoperand.token.text == bin.rhsoperand.token.text
		end)
		:replace(function(bin)
			return `math.isnan({(bin.lhsoperand :: luau.AstExprLocal).token.text})`
		end)
		:print()
end

return transform
