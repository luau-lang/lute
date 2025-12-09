local printer = require("@std/syntax/printer")
local visitor = require("@std/syntax/visitor")
local syntax = require("@std/syntax")

local function transformation(ctx)
	local v = visitor.create()

	v.visitExprBinary = function(node: syntax.AstExprBinary)
		if node.operator.text ~= "~=" then
			return true
		end

		if node.lhsoperand.tag ~= "local" or node.rhsoperand.tag ~= "local" then
			return true
		end

		if node.lhsoperand.token.text ~= node.rhsoperand.token.text then
			return true
		end

		local operand: syntax.AstExprLocal = node.lhsoperand
		operand.token.leadingtrivia = {}
		operand.token.trailingtrivia = {}
		local location: syntax.span = operand.token.location;

		-- transform node into an AstExprCall
		(node :: any).operator = nil
		(node :: any).lhsoperand = nil
		(node :: any).rhsoperand = nil

		((node :: any) :: syntax.AstExprCall).tag = "call"

		local func: syntax.AstExprGlobal = {
			kind = "expr",
			tag = "global",
			name = {
				istoken = true,
				leadingtrivia = {},
				location = location,
				text = "math.isnan",
				trailingtrivia = {},
			},
		}
		((node :: any) :: syntax.AstExprCall).func = func

		local openparens: syntax.Token<"("> = {
			istoken = true,
			leadingtrivia = {},
			location = syntax.span.create({
				beginline = location.beginline,
				begincolumn = location.begincolumn + #"math.isnan",
				endline = location.endline,
				endcolumn = location.endcolumn + #"math.isnan" + 1,
			}),
			text = "(",
			trailingtrivia = {},
		}
		((node :: any) :: syntax.AstExprCall).openparens = openparens

		local arguments: syntax.Punctuated<syntax.AstExpr> = { { node = operand } }
		((node :: any) :: syntax.AstExprCall).arguments = arguments

		local closeparens: syntax.Token<")"> = {
			istoken = true,
			leadingtrivia = {},
			location = syntax.span.create({
				beginline = location.beginline,
				begincolumn = location.begincolumn + #"math.isnan(" + #operand.token.text,
				endline = location.endline,
				endcolumn = location.endcolumn + #"math.isnan(" + #operand.token.text + 1,
			}),
			text = ")",
			trailingtrivia = {},
		}
		((node :: any) :: syntax.AstExprCall).closeparens = closeparens;

		((node :: any) :: syntax.AstExprCall).self = false

		local argLocation: syntax.span = syntax.span.create({
			beginline = location.beginline,
			begincolumn = location.begincolumn + #"math.isnan(",
			endline = location.endline,
			endcolumn = location.begincolumn + #"math.isnan(" + #operand.token.text,
		});
		((node :: any) :: syntax.AstExprCall).argLocation = argLocation

		return false
	end

	visitor.visitblock(ctx.parseresult.root, v)

	return printer.printfile(ctx.parseresult)
end

return transformation
