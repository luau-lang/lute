--!strict
-- @std/syntax/printer

local luau = require("@std/luau")
local types = require("./types")
local visitor = require("./visitor")

local printerLib = {}

type PrintVisitor = visitor.Visitor & {
	result: buffer,
	cursor: number,
	replacements: types.replacements,
	write: (self: PrintVisitor, str: string) -> (),
	printTrivia: (self: PrintVisitor, trivia: luau.Trivia) -> (),
	printTriviaList: (self: PrintVisitor, trivia: { luau.Trivia }) -> (),
	printToken: (self: PrintVisitor, token: luau.Token) -> (),
	printString: (self: PrintVisitor, expr: luau.AstExprConstantString | luau.AstTypeSingletonString) -> (),
	printInterpolatedString: (self: PrintVisitor, expr: luau.AstExprInterpString) -> (),
	printReplacement: (self: PrintVisitor, node: luau.AstNode, replacement: types.replacement) -> (),
}
local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function printTrivia(self: PrintVisitor, trivia: luau.Trivia)
	if trivia.tag == "whitespace" or trivia.tag == "comment" or trivia.tag == "blockcomment" then
		self:write(trivia.text)
	else
		exhaustiveMatch(trivia.tag)
	end
end

local function printTriviaList(self: PrintVisitor, trivia: { luau.Trivia })
	for _, trivia in trivia do
		self:printTrivia(trivia)
	end
end

local function printToken(self: PrintVisitor, token: luau.Token)
	self:printTriviaList(token.leadingtrivia)
	self:write(token.text)
	self:printTriviaList(token.trailingtrivia)
end

local function printString(self: PrintVisitor, expr: luau.AstExprConstantString | luau.AstTypeSingletonString)
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

local function printInterpolatedString(self: PrintVisitor, expr: luau.AstExprInterpString)
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

local function printReplacement(self: PrintVisitor, node: luau.AstNode, replacement: types.replacement)
	if typeof(replacement) == "string" then
		self:write(replacement)
	elseif replacement.kind ~= nil then -- LUAUFIX: type solver should know replacement might have a kind field
		-- TODO: preserve trivia
		if replacement.kind == "expr" then
			return visitor.visitexpression(replacement, self) -- LUAUFIX: refine replacement to be AstExpr
		elseif replacement.kind == "stat" then
			return visitor.visitstatement(replacement, self) -- LUAUFIX: refine replacement to be AstStat
		elseif replacement.kind == "type" then
			return visitor.visittype(replacement, self) -- LUAUFIX: refine replacement to be AstType
		elseif replacement.kind == "typepack" then
			return visitor.visittypepack(replacement, self) -- LUAUFIX: refine replacement to be AstTypePack
		elseif replacement.kind == "local" then
			error("TODO: Add visit function to visit library")
		elseif replacement.kind == "attribute" then
			error("TODO: Add visit function to visit library")
		else
			error(`Unknown node kind in replacement: {replacement.kind}`)
		end
	elseif replacement.tag ~= nil then -- LUAUFIX: type solver should know replacement might have a tag field (if it's a delta or removal)
		self.replacements[node] = nil -- Prevent infinite recursion
		if replacement.tag == "append" then
			self:printReplacement(node, node)
			self:printReplacement(node, replacement.content)
		elseif replacement.tag == "prepend" then
			self:printReplacement(node, replacement.content)
			self:printReplacement(node, node)
		elseif replacement.tag == "replace" then
			self:printReplacement(node, replacement.content)
		elseif replacement.tag == "remove" then
			return
		else
			error("Unsupported tag for replacement")
		end
	else
		self.replacements[node] = nil -- Prevent infinite recursion
		-- Serialize prepends, then replaces, then appends (table.sort isn't stable)
		for _, delta in replacement do
			if delta.tag == "prepend" then
				self:printReplacement(node, delta.content)
			end
		end
		for _, delta in replacement do
			if delta.tag == "replace" then
				self:printReplacement(node, delta.content)
			end
		end
		for _, delta in replacement do
			if delta.tag == "append" then
				self:printReplacement(node, delta.content)
			end
		end
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
	local function maybeReplace(node: luau.AstNode): boolean
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

	printer.result = result
	printer.cursor = cursor
	printer.replacements = if replacements ~= nil then replacements else {}
	printer.write = write
	printer.printTrivia = printTrivia
	printer.printTriviaList = printTriviaList
	printer.printToken = printToken
	printer.printString = printString
	printer.printInterpolatedString = printInterpolatedString
	printer.printReplacement = printReplacement

	printer.visitBlock = maybeReplace
	printer.visitBlockEnd = maybeReplace
	printer.visitIf = maybeReplace
	printer.visitWhile = maybeReplace
	printer.visitRepeat = maybeReplace
	printer.visitReturn = maybeReplace
	printer.visitLocalDeclaration = maybeReplace
	printer.visitLocalDeclarationEnd = maybeReplace
	printer.visitFor = maybeReplace
	printer.visitForIn = maybeReplace
	printer.visitAssign = maybeReplace
	printer.visitCompoundAssign = maybeReplace
	printer.visitFunction = maybeReplace
	printer.visitLocalFunction = maybeReplace
	printer.visitTypeAlias = maybeReplace
	printer.visitStatTypeFunction = maybeReplace

	printer.visitExpression = maybeReplace
	printer.visitExpressionEnd = maybeReplace
	printer.visitLocalReference = maybeReplace
	printer.visitGlobal = maybeReplace
	printer.visitCall = maybeReplace
	printer.visitUnary = maybeReplace
	printer.visitBinary = maybeReplace
	printer.visitAnonymousFunction = maybeReplace
	printer.visitTableItem = maybeReplace
	printer.visitTable = maybeReplace
	printer.visitIndexName = maybeReplace
	printer.visitIndexExpr = maybeReplace
	printer.visitGroup = maybeReplace
	printer.visitInterpolatedString = function(node: luau.AstExprInterpString)
		printer:printInterpolatedString(node)
		return false
	end
	printer.visitTypeAssertion = maybeReplace
	printer.visitIfExpression = maybeReplace

	printer.visitTypeReference = maybeReplace
	printer.visitTypeBoolean = maybeReplace
	printer.visitTypeString = function(node: luau.AstTypeSingletonString)
		printer:printString(node)
		return false
	end
	printer.visitTypeTypeof = maybeReplace
	printer.visitTypeGroup = maybeReplace
	printer.visitTypeUnion = maybeReplace
	printer.visitTypeIntersection = maybeReplace
	printer.visitTypeArray = maybeReplace
	printer.visitTypeTable = maybeReplace
	printer.visitTypeFunction = maybeReplace

	printer.visitTypePackExplicit = maybeReplace
	printer.visitTypePackGeneric = maybeReplace
	printer.visitTypePackVariadic = maybeReplace

	printer.visitToken = function(node: luau.Token)
		printer:printToken(node)
		return false
	end
	printer.visitNil = maybeReplace
	printer.visitString = function(node: luau.AstExprConstantString)
		printer:printString(node)
		return false
	end
	printer.visitBoolean = maybeReplace
	printer.visitNumber = maybeReplace
	printer.visitLocal = maybeReplace
	printer.visitVarargs = maybeReplace

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
