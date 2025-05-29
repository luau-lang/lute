--!strict
local luau = require("@lute/luau")
local visitor = require("./visitor")

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
	return printTriviaList(token.leadingTrivia) .. token.text .. printTriviaList(token.trailingTrivia)
end

local function printString(expr: luau.AstExprConstantString): string
	local result = printTriviaList(expr.leadingTrivia)

	if expr.quoteStyle == "single" then
		result ..= `'{expr.text}'`
	elseif expr.quoteStyle == "double" then
		result ..= `"{expr.text}"`
	elseif expr.quoteStyle == "block" then
		local equals = string.rep("=", expr.blockDepth)
		result ..= `[{equals}[{expr.text}]{equals}]`
	elseif expr.quoteStyle == "interp" then
		result ..= "`" .. expr.text .. "`"
	else
		return exhaustiveMatch(expr.quoteStyle)
	end

	result ..= printTriviaList(expr.trailingTrivia)
	return result
end

local function printInterpolatedString(expr: luau.AstExprInterpString): string
	local result = ""

	for i = 1, #expr.strings do
		result ..= printTriviaList(expr.strings[i].leadingTrivia)
		if i == 1 then
			result ..= "`"
		else
			result ..= "}"
		end
		result ..= expr.strings[i].text

		if i == #expr.strings then
			result ..= "`"
			result ..= printTriviaList(expr.strings[i].trailingTrivia)
		else
			result ..= "{"
			result ..= printTriviaList(expr.strings[i].trailingTrivia)
			result ..= printExpr(expr.expressions[i])
		end
	end

	return result
end

type PrintVisitor = visitor.Visitor & {
	result: buffer,
	cursor: number,
}

local function printVisitor()
	local printer = visitor.createVisitor() :: PrintVisitor

	printer.result = buffer.create(1024)
	printer.cursor = 0

	local function write(str: string)
		local totalSize = printer.cursor + #str
		local bufferSize = buffer.len(printer.result)

		if totalSize >= bufferSize then
			repeat
				bufferSize *= 2
			until bufferSize >= totalSize

			local newBuffer = buffer.create(bufferSize)
			buffer.copy(newBuffer, 0, printer.result)
			printer.result = newBuffer
		end

		buffer.writestring(printer.result, printer.cursor, str)
		printer.cursor = totalSize
	end

	printer.visitToken = function(node: luau.Token)
		write(printToken(node))
		return false
	end

	printer.visitString = function(node: luau.AstExprConstantString)
		write(printString(node))
		return false
	end

	printer.visitTypeString = function(node: luau.AstTypeSingletonString)
		write(printString(node))
		return false
	end

	printer.visitInterpolatedString = function(node: luau.AstExprInterpString)
		write(printInterpolatedString(node))
		return false
	end

	return printer
end

--- Returns a string representation of an AstStatBlock
local function printBlock(block: luau.AstStatBlock): string
	local printer = printVisitor()
	visitor.visitBlock(block, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

--- Returns a string representation of an AstExpr
function printExpr(block: luau.AstExpr): string
	local printer = printVisitor()
	visitor.visitExpression(block, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

function printFile(result: { root: luau.AstStatBlock, eof: luau.Eof }): string
	local printer = printVisitor()
	visitor.visitBlock(result.root, printer)
	visitor.visitToken(result.eof, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

return {
	print = printBlock,
	printexpr = printExpr,
	printfile = printFile,
}
