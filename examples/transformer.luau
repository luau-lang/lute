local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local visitor = require("@std/syntax/visitor")
local luau = require("@lute/luau")

function transformation(ctx)
	local parsedResult = parser.parsefile(ctx.source)

	local v = visitor.create()

	v.visitBinary = function(node: luau.AstExprBinary)
		if node.operator.text ~= "~=" then
			return true
		end

		if node.lhsoperand.tag ~= "local" or node.rhsoperand.tag ~= "local" then
			return true
		end

		if node.lhsoperand.token.text ~= node.rhsoperand.token.text then
			return true
		end

		local operand: luau.AstExprLocal = node.lhsoperand
		operand.token.leadingtrivia = {}
		operand.token.trailingtrivia = {}
		local openingPosition: luau.Position = operand.token.position;

		-- transform node into an AstExprCall
		(node :: any).operator = nil
		(node :: any).lhsoperand = nil
		(node :: any).rhsoperand = nil

		((node :: any) :: luau.AstExprCall).tag = "call"

		local func: luau.AstExpr = {
			tag = "global",
			name = {
				leadingtrivia = {},
				position = openingPosition,
				text = "math.isnan",
				trailingtrivia = {},
			},
		}
		((node :: any) :: luau.AstExprCall).func = func

		local openparens: luau.Token<"("> = {
			leadingtrivia = {},
			position = { line = openingPosition.line, column = openingPosition.column + #"math.isnan" },
			text = "(",
			trailingtrivia = {},
		}
		((node :: any) :: luau.AstExprCall).openparens = openparens

		local arguments: luau.Punctuated<luau.AstExpr> = { { node = operand } }
		((node :: any) :: luau.AstExprCall).arguments = arguments

		local closeparens: luau.Token<")"> = {
			leadingtrivia = {},
			position = {
				line = openingPosition.line,
				column = openingPosition.column + #"math.isnan(" + #operand.token.text,
			},
			text = ")",
			trailingtrivia = {},
		}
		((node :: any) :: luau.AstExprCall).closeparens = closeparens;

		((node :: any) :: luau.AstExprCall).self = false

		local argLocation: luau.Location = {
			begin = { line = openingPosition.line, column = openingPosition.column + #"math.isnan(" },
			["end"] = {
				line = openingPosition.line,
				column = openingPosition.column + #"math.isnan(" + #operand.token.text,
			},
		}
		((node :: any) :: luau.AstExprCall).argLocation = argLocation

		return false
	end

	visitor.visitblock(parsedResult.root, v)

	return printer.printfile(parsedResult)
end

return transformation
