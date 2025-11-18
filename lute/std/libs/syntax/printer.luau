--!strict
-- @std/syntax/printer

local triviaUtils = require("./utils/trivia")
local types = require("./types")
local visitor = require("./visitor")

local printerLib = {}

type PrintVisitor = visitor.Visitor & {
	result: buffer,
	cursor: number,
	replacements: types.replacements,
	write: (self: PrintVisitor, str: string) -> (),
	printTrivia: (self: PrintVisitor, trivia: types.Trivia) -> (),
	printTriviaList: (self: PrintVisitor, trivia: { types.Trivia }) -> (),
	printToken: (self: PrintVisitor, token: types.Token) -> (),
	printString: (self: PrintVisitor, expr: types.AstExprConstantString | types.AstTypeSingletonString) -> (),
	printInterpolatedString: (self: PrintVisitor, expr: types.AstExprInterpString) -> (),
	printReplacement: (self: PrintVisitor, node: types.AstNode, replacement: types.replacement) -> (),
}
local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function printTrivia(self: PrintVisitor, trivia: types.Trivia)
	if trivia.tag == "whitespace" or trivia.tag == "comment" or trivia.tag == "blockcomment" then
		self:write(trivia.text)
	else
		exhaustiveMatch(trivia.tag)
	end
end

local function printTriviaList(self: PrintVisitor, trivia: { types.Trivia })
	for _, trivia in trivia do
		self:printTrivia(trivia)
	end
end

local function printToken(self: PrintVisitor, token: types.Token)
	if self.replacements[token] ~= nil then
		self:printReplacement(token, self.replacements[token])
		return
	end

	self:printTriviaList(token.leadingtrivia)
	self:write(token.text)
	self:printTriviaList(token.trailingtrivia)
end

local function printString(self: PrintVisitor, expr: types.AstExprConstantString | types.AstTypeSingletonString)
	if self.replacements[expr] ~= nil then
		self:printReplacement(expr, self.replacements[expr])
		return
	end

	self:printTriviaList(expr.leadingtrivia)

	if expr.quotestyle == "single" then
		self:write(`'{expr.text}'`)
	elseif expr.quotestyle == "double" then
		self:write(`"{expr.text}"`)
	elseif expr.quotestyle == "block" then
		local equals = string.rep("=", expr.blockdepth)
		self:write(`[{equals}[{expr.text}]{equals}]`)
	elseif expr.quotestyle == "interp" then
		self:write("`" .. expr.text .. "`")
	else
		exhaustiveMatch(expr.quotestyle)
	end

	self:printTriviaList(expr.trailingtrivia)
end

local function printInterpolatedString(self: PrintVisitor, expr: types.AstExprInterpString)
	if self.replacements[expr] ~= nil then
		self:printReplacement(expr, self.replacements[expr])
		return
	end

	for i = 1, #expr.strings do
		self:printTriviaList(expr.strings[i].leadingtrivia)
		if i == 1 then
			self:write("`")
		else
			self:write("}")
		end
		self:write(expr.strings[i].text)

		if i == #expr.strings then
			self:write("`")
			self:printTriviaList(expr.strings[i].trailingtrivia)
		else
			self:write("{")
			self:printTriviaList(expr.strings[i].trailingtrivia)
			visitor.visitexpression(expr.expressions[i], self)
		end
	end
end

local function printReplacement(self: PrintVisitor, node: types.AstNode, replacement: types.replacement)
	local leftmostTrivia = triviaUtils.leftmosttrivia(node)
	if leftmostTrivia ~= nil then
		self:printTriviaList(leftmostTrivia)
	end

	if typeof(replacement) == "string" then
		self:write(replacement)
	elseif replacement.kind ~= nil then -- LUAUFIX: type solver upset comparing string singleton union to nil
		-- TODO: preserve trivia
		visitor.visit(replacement, self)
	else
		error("Unsupported replacement type")
	end

	local rightmostTrivia = triviaUtils.rightmosttrivia(node)
	if rightmostTrivia ~= nil then
		self:printTriviaList(rightmostTrivia)
	end
end

local function write(self: PrintVisitor, str: string)
	local totalSize = self.cursor + #str
	local bufferSize = buffer.len(self.result)

	if totalSize >= bufferSize then
		repeat
			bufferSize *= 2
		until bufferSize >= totalSize

		local newBuffer = buffer.create(bufferSize)
		buffer.copy(newBuffer, 0, self.result)
		self.result = newBuffer
	end

	buffer.writestring(self.result, self.cursor, str)
	self.cursor = totalSize
end

local function printVisitor(replacements: types.replacements?)
	local result = buffer.create(1024)
	local cursor = 0

	local printer: PrintVisitor = {} :: PrintVisitor

	-- The visitor library doesn't use methods, so we access replacements through a closure
	local function maybeReplace(node: types.AstNode): boolean
		if replacements == nil then
			return true
		end
		local replacement = replacements[node]
		if replacement == nil then
			return true
		end
		printer:printReplacement(node, replacement)
		return false
	end

	printer = visitor.create(maybeReplace) :: PrintVisitor

	printer.result = result
	printer.cursor = cursor
	printer.replacements = if replacements ~= nil then replacements else {} :: types.replacements
	printer.write = write
	printer.printTrivia = printTrivia
	printer.printTriviaList = printTriviaList
	printer.printToken = printToken
	printer.printString = printString
	printer.printInterpolatedString = printInterpolatedString
	printer.printReplacement = printReplacement
	printer.visitInterpolatedString = function(node: types.AstExprInterpString)
		printer:printInterpolatedString(node)
		return false
	end
	printer.visitTypeString = function(node: types.AstTypeSingletonString)
		printer:printString(node)
		return false
	end
	printer.visitToken = function(node: types.Token)
		printer:printToken(node)
		return false
	end
	printer.visitString = function(node: types.AstExprConstantString)
		printer:printString(node)
		return false
	end

	return printer
end

function printerLib.printnode(node: types.AstNode, replacements: types.replacements?): string
	local printer = printVisitor(replacements)
	visitor.visit(node, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

function printerLib.printfile(
	result: { root: types.AstStatBlock, eof: types.Eof },
	replacements: types.replacements?
): string
	local printer = printVisitor(replacements)
	visitor.visitblock(result.root, printer)
	visitor.visittoken(result.eof, printer)
	return buffer.readstring(printer.result, 0, printer.cursor)
end

return table.freeze(printerLib)
