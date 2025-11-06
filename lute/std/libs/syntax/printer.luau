--!strict
-- @std/syntax/printer

local luau = require("@std/luau")
local types = require("./types")
local visitor = require("./visitor")

local printerLib = {}

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function printTrivia(trivia: luau.Trivia): string
	if trivia.tag == "whitespace" or trivia.tag == "comment" or trivia.tag == "blockcomment" then
		return trivia.text
	else
		return exhaustiveMatch(trivia.tag)
	end
end

local function printTriviaList(trivia: { luau.Trivia })
	local result = ""
	for _, trivia in trivia do
		result ..= printTrivia(trivia)
	end
	return result
end

local function printToken(token: luau.Token): string
	return printTriviaList(token.leadingtrivia) .. token.text .. printTriviaList(token.trailingtrivia)
end

local function printString(expr: luau.AstExprConstantString | luau.AstTypeSingletonString): string
	local result = printTriviaList(expr.leadingtrivia)

	if expr.quotestyle == "single" then
		result ..= `'{expr.text}'`
	elseif expr.quotestyle == "double" then
		result ..= `"{expr.text}"`
	elseif expr.quotestyle == "block" then
		local equals = string.rep("=", expr.blockdepth)
		result ..= `[{equals}[{expr.text}]{equals}]`
	elseif expr.quotestyle == "interp" then
		result ..= "`" .. expr.text .. "`"
	else
		return exhaustiveMatch(expr.quotestyle)
	end

	result ..= printTriviaList(expr.trailingtrivia)
	return result
end

local function printInterpolatedString(expr: luau.AstExprInterpString, replacements: types.replacements?): string
	local result = ""

	for i = 1, #expr.strings do
		result ..= printTriviaList(expr.strings[i].leadingtrivia)
		if i == 1 then
			result ..= "`"
		else
			result ..= "}"
		end
		result ..= expr.strings[i].text

		if i == #expr.strings then
			result ..= "`"
			result ..= printTriviaList(expr.strings[i].trailingtrivia)
		else
			result ..= "{"
			result ..= printTriviaList(expr.strings[i].trailingtrivia)
			result ..= printerLib.printexpr(expr.expressions[i], replacements)
		end
	end

	return result
end

local function printReplacement(replacement: types.replacement): string
	error("TODO")
end

type PrintVisitor = visitor.Visitor & {
	result: buffer,
	cursor: number,
}

local function printVisitor(replacements: types.replacements?)
	local result = buffer.create(1024)
	local cursor = 0

	local function write(str: string)
		local totalSize = cursor + #str
		local bufferSize = buffer.len(result)

		if totalSize >= bufferSize then
			repeat
				bufferSize *= 2
			until bufferSize >= totalSize

			local newBuffer = buffer.create(bufferSize)
			buffer.copy(newBuffer, 0, result)
			result = newBuffer
		end

		buffer.writestring(result, cursor, str)
		cursor = totalSize
	end

	local function maybeReplace(node: luau.AstNode): boolean
		if replacements == nil then
			return true
		end
		local replacement = replacements[node]
		if replacement == nil then
			return true
		end
		write(printReplacement(replacement))
		return false
	end

	local printer: PrintVisitor = {
		visitBlock = maybeReplace,
		visitBlockEnd = maybeReplace,
		visitIf = maybeReplace,
		visitWhile = maybeReplace,
		visitRepeat = maybeReplace,
		visitReturn = maybeReplace,
		visitLocalDeclaration = maybeReplace,
		visitLocalDeclarationEnd = maybeReplace,
		visitFor = maybeReplace,
		visitForIn = maybeReplace,
		visitAssign = maybeReplace,
		visitCompoundAssign = maybeReplace,
		visitFunction = maybeReplace,
		visitLocalFunction = maybeReplace,
		visitTypeAlias = maybeReplace,
		visitStatTypeFunction = maybeReplace,

		visitExpression = maybeReplace,
		visitExpressionEnd = maybeReplace,
		visitLocalReference = maybeReplace,
		visitGlobal = maybeReplace,
		visitCall = maybeReplace,
		visitUnary = maybeReplace,
		visitBinary = maybeReplace,
		visitAnonymousFunction = maybeReplace,
		visitTableItem = maybeReplace,
		visitTable = maybeReplace,
		visitIndexName = maybeReplace,
		visitIndexExpr = maybeReplace,
		visitGroup = maybeReplace,
		visitInterpolatedString = function(node: luau.AstExprInterpString)
			write(printInterpolatedString(node, replacements))
			return false
		end,
		visitTypeAssertion = maybeReplace,
		visitIfExpression = maybeReplace,

		visitTypeReference = maybeReplace,
		visitTypeBoolean = maybeReplace,
		visitTypeString = function(node: luau.AstTypeSingletonString)
			write(printString(node))
			return false
		end,
		visitTypeTypeof = maybeReplace,
		visitTypeGroup = maybeReplace,
		visitTypeUnion = maybeReplace,
		visitTypeIntersection = maybeReplace,
		visitTypeArray = maybeReplace,
		visitTypeTable = maybeReplace,
		visitTypeFunction = maybeReplace,

		visitTypePackExplicit = maybeReplace,
		visitTypePackGeneric = maybeReplace,
		visitTypePackVariadic = maybeReplace,

		visitToken = function(node: luau.Token)
			write(printToken(node))
			return false
		end,
		visitNil = maybeReplace,
		visitString = function(node: luau.AstExprConstantString)
			write(printString(node))
			return false
		end,
		visitBoolean = maybeReplace,
		visitNumber = maybeReplace,
		visitLocal = maybeReplace,
		visitVarargs = maybeReplace,
		result = result,
		cursor = cursor,
	}

	return printer
end

function printNode<T>(node: T, visit: (node: T, visitor: visitor.Visitor) -> (), replacements: types.replacements?): string
	local printer = printVisitor(replacements)
	visit(node, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

--- Returns a string representation of an AstExpr
function printerLib.printexpr(expr: luau.AstExpr, replacements: types.replacements?): string
	return printNode(expr, visitor.visitexpression, replacements)
end

--- Returns a string representation of an AstStat
function printerLib.printstatement(statement: luau.AstStat, replacements: types.replacements?): string
	return printNode(statement, visitor.visitstatement, replacements)
end

-- Returns a string representation of an AstType
function printerLib.printtype(type: luau.AstType, replacements: types.replacements?): string
	return printNode(type, visitor.visittype, replacements)
end

function printerLib.printfile(
	result: { root: luau.AstStatBlock, eof: luau.Eof },
	replacements: types.replacements?
): string
	local printer = printVisitor(replacements)
	visitor.visitblock(result.root, printer)
	visitor.visittoken(result.eof, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

return table.freeze(printerLib)
