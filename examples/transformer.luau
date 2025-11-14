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
		local openingPosition: syntax.Position = operand.token.position;

		-- transform node into an AstExprCall
		(node :: any).operator = nil
		(node :: any).lhsoperand = nil
		(node :: any).rhsoperand = nil

		((node :: any) :: syntax.AstExprCall).tag = "call"

		local func: syntax.AstExpr = {
			tag = "global",
			name = {
				leadingtrivia = {},
				position = openingPosition,
				text = "math.isnan",
				trailingtrivia = {},
			},
		}
		((node :: any) :: syntax.AstExprCall).func = func

		local openparens: syntax.Token<"("> = {
			leadingtrivia = {},
			position = { line = openingPosition.line, column = openingPosition.column + #"math.isnan" },
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

		local argLocation: syntax.span = span.create(
    		openingPosition.line,
    		openingPosition.column + #"math.isnan(",
    		openingPosition.line,
    		openingPosition.column + #"math.isnan(" + #operand.token.text,
  		)
		((node :: any) :: syntax.AstExprCall).argLocation = argLocation

		return false
	end

	visitor.visitblock(ctx.parseresult.root, v)

	return printer.printfile(ctx.parseresult)
end

return transformation
