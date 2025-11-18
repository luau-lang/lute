local printer = require("@std/syntax/printer")
local visitor = require("@std/syntax/visitor")
local syntax = require("@std/syntax")

local function transformation(ctx)
	local v = visitor.create()

	v.visitBinary = function(node: syntax.AstExprBinary)
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
		local location: syntax.span = operand.token.location

		-- transform node into an AstExprCall
		(node :: any).operator = nil
		(node :: any).lhsoperand = nil
		(node :: any).rhsoperand = nil

		((node :: any) :: syntax.AstExprCall).tag = "call"

		local func: syntax.AstExpr = {
			tag = "global",
			name = {
				leadingtrivia = {},
				location = location,
				text = "math.isnan",
				trailingtrivia = {},
			},
		}
		((node :: any) :: syntax.AstExprCall).func = func

		local openparens: syntax.Token<"("> = {
			leadingtrivia = {},
			location = location, --  + #"math.isnan", we want to move this span, we should probably have `span:advance()` or something
			text = "(",
			trailingtrivia = {},
		}
		((node :: any) :: syntax.AstExprCall).openparens = openparens

		local arguments: syntax.Punctuated<syntax.AstExpr> = { { node = operand } }
		((node :: any) :: syntax.AstExprCall).arguments = arguments

		local closeparens: syntax.Token<")"> = {
			leadingtrivia = {},
			position = {
				line = openingPosition.line,
				column = openingPosition.column + #"math.isnan(" + #operand.token.text,
			},
			text = ")",
			trailingtrivia = {},
		}
		((node :: any) :: syntax.AstExprCall).closeparens = closeparens;

		((node :: any) :: syntax.AstExprCall).self = false

		local newBeginColumn = location.begincolumn + #"math.isnan("
		local newEndColumn = location.endcolumn + #"math.isnan(" + #operand.token.text
		local argLocation: syntax.span = syntax.span.create(location.beginline, newBeginColumn, location.endline, newEndColumn)
		((node :: any) :: syntax.AstExprCall).argLocation = argLocation

		return false
	end

	visitor.visitblock(ctx.parseresult.root, v)

	return printer.printfile(ctx.parseresult)
end

return transformation
