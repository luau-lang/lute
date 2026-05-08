--!nonstrict
local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local visitor = require("@std/syntax/visitor")

local format = {}

local INDENT = "\t"
local MAX_BLANK_LINES = 1

local KEYWORDS: { [string]: boolean } = {
	["and"] = true,
	["break"] = true,
	["continue"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["export"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["type"] = true,
	["until"] = true,
	["while"] = true,
}

local BINARY_OPERATORS: { [string]: boolean } = {
	["="] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["//="] = true,
	["%="] = true,
	["^="] = true,
	["..="] = true,
	["=="] = true,
	["~="] = true,
	["<"] = true,
	[">"] = true,
	["<="] = true,
	[">="] = true,
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["//"] = true,
	["%"] = true,
	["^"] = true,
	[".."] = true,
	["::"] = true,
	["->"] = true,
	["|"] = true,
	["&"] = true,
	["and"] = true,
	["or"] = true,
}

local OPENERS: { [string]: boolean } = {
	["("] = true,
	["["] = true,
	["{"] = true,
}

local CLOSERS: { [string]: boolean } = {
	[")"] = true,
	["]"] = true,
	["}"] = true,
}

type FormatToken = {
	text: string,
	kind: string,
	leadingNewlines: number,
	node: any?,
	role: string?,
	unary: boolean?,
	trailingCommaAfter: boolean?,
	multilineClose: boolean?,
	dedentedBefore: boolean?,
	functionBodyStartedBefore: boolean?,
}

type Replacement = {
	content: string,
	preserveTrivia: boolean,
}

local function countNewlines(text: string): number
	local _, count = text:gsub("\n", "")
	return count
end

local function textEquals(left: string, right: string): boolean
	return left == right
end

local function classifyText(text: string): string
	if text == "" then
		return "eof"
	elseif KEYWORDS[text] then
		return "keyword"
	elseif text:match("^%d") then
		return "number"
	elseif text:match("^[%a_]") then
		return "identifier"
	else
		return "symbol"
	end
end

local function quoteString(text: string, quoteStyle: string, blockDepth: number?): string
	if quoteStyle == "single" then
		if text:find('"', 1, true) == nil then
			return '"' .. text .. '"'
		end
		return "'" .. text .. "'"
	elseif quoteStyle == "double" then
		return '"' .. text:gsub([[\']], "'") .. '"'
	elseif quoteStyle == "block" then
		local equals = string.rep("=", blockDepth or 0)
		return `[{equals}[{text}]{equals}]`
	elseif quoteStyle == "interp" then
		return "`" .. text .. "`"
	else
		return text
	end
end

local function rawInterpolatedString(node): string
	local pieces = {}

	for index = 1, #node.strings do
		if index == 1 then
			table.insert(pieces, "`")
		else
			table.insert(pieces, "}")
		end

		table.insert(pieces, node.strings[index].text)

		if index == #node.strings then
			table.insert(pieces, "`")
		else
			table.insert(pieces, "{")
			local expressionText = printer.printNode(node.expressions[index]):match("^%s*(.-)%s*$") or ""
			table.insert(pieces, expressionText)
		end
	end

	return table.concat(pieces)
end

local function itemText(node): string
	if node.kind == "token" then
		return node.text
	elseif node.kind == "expr" and node.tag == "string" then
		return quoteString(node.token.text, node.quoteStyle, node.blockDepth)
	elseif node.kind == "type" and node.tag == "string" then
		return quoteString(node.token.text, node.quoteStyle)
	elseif node.kind == "expr" and node.tag == "interpolatedstring" then
		return rawInterpolatedString(node)
	else
		return printer.printNode(node)
	end
end

local function itemLeadingTrivia(node)
	if node.kind == "token" then
		return node.leadingTrivia
	elseif node.kind == "expr" and node.tag == "string" then
		return node.token.leadingTrivia
	elseif node.kind == "type" and node.tag == "string" then
		return node.token.leadingTrivia
	elseif node.kind == "expr" and node.tag == "interpolatedstring" then
		return node.strings[1].leadingTrivia
	else
		return {}
	end
end

local function itemTrailingTrivia(node)
	if node.kind == "token" then
		return node.trailingTrivia
	elseif node.kind == "expr" and node.tag == "string" then
		return node.token.trailingTrivia
	elseif node.kind == "type" and node.tag == "string" then
		return node.token.trailingTrivia
	elseif node.kind == "expr" and node.tag == "interpolatedstring" then
		return node.strings[#node.strings].trailingTrivia
	else
		return {}
	end
end

local function mark(roles, token, role: string)
	if token ~= nil and roles[token] == nil then
		roles[token] = role
	end
end

local function markTrailingComma(trailingCommas, token)
	if token ~= nil then
		trailingCommas[token] = true
	end
end

local function markGenerics(roles, node)
	mark(roles, node.openGenerics, "genericOpen")
	mark(roles, node.closeGenerics, "genericClose")
end

local function markLastReplacementItem(trailingCommas, node)
	local lastItem = nil
	local finder = visitor.create()

	finder.visitToken = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitExprConstantString = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitExprInterpString = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitTypeSingletonString = function(candidate)
		lastItem = candidate
		return false
	end

	visitor.visit(node, finder)
	markTrailingComma(trailingCommas, lastItem)
end

local function markLastReplacementRole(roles, node, role: string)
	local lastItem = nil
	local finder = visitor.create()

	finder.visitToken = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitExprConstantString = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitExprInterpString = function(candidate)
		lastItem = candidate
		return false
	end

	finder.visitTypeSingletonString = function(candidate)
		lastItem = candidate
		return false
	end

	visitor.visit(node, finder)
	mark(roles, lastItem, role)
end

local function tokenHasLeadingNewline(token): boolean
	if token == nil then
		return false
	end

	for _, trivia in token.leadingTrivia do
		if trivia.tag == "whitespace" and countNewlines(trivia.text) > 0 then
			return true
		end
	end

	return false
end

local function collectReplacementItems(parseResult, roles, trailingCommas)
	local items = {}
	local collect = visitor.create()

	collect.visitLocal = function(node)
		mark(roles, node.colon, "typeColon")
		return true
	end

	collect.visitExprFunction = function(node)
		markGenerics(roles, node)
		mark(roles, node.closeParens, "functionParamsClose")
		mark(roles, node.varargColon, "typeColon")
		mark(roles, node.returnSpecifier, "typeColon")
		mark(roles, node.endKeyword, "functionEnd")
		if node.returnAnnotation ~= nil then
			markLastReplacementRole(roles, node.returnAnnotation, "functionReturnAnnotationEnd")
		end
		return true
	end

	collect.visitExprInstantiate = function(node)
		mark(roles, node.leftArrow1, "genericOpen")
		mark(roles, node.leftArrow2, "genericOpen")
		mark(roles, node.rightArrow1, "genericClose")
		mark(roles, node.rightArrow2, "genericClose")
		return true
	end

	collect.visitExprIfElse = function(node)
		mark(roles, node.thenKeyword, "ifExpressionKeyword")
		mark(roles, node.elseKeyword, "ifExpressionKeyword")
		for _, elseifNode in node.elseifs do
			mark(roles, elseifNode.elseIfKeyword, "ifExpressionKeyword")
			mark(roles, elseifNode.thenKeyword, "ifExpressionKeyword")
		end
		return true
	end

	collect.visitStatTypeAlias = function(node)
		markGenerics(roles, node)
		return true
	end

	collect.visitTypeReference = function(node)
		mark(roles, node.openParameters, "genericOpen")
		mark(roles, node.closeParameters, "genericClose")
		return true
	end

	collect.visitTypeTable = function(node)
		mark(roles, node.closeBrace, "tableClose")
		local lastEntry = node.entries[#node.entries]
		if lastEntry ~= nil and lastEntry.separator == nil and tokenHasLeadingNewline(node.closeBrace) then
			markLastReplacementItem(trailingCommas, lastEntry.value)
		end

		for _, entry in node.entries do
			mark(roles, entry.colon, "typeColon")
		end
		return true
	end

	collect.visitTypeFunction = function(node)
		markGenerics(roles, node)
		mark(roles, node.returnArrow, "typeReturnArrow")
		for _, parameter in node.parameters do
			mark(roles, parameter.node and parameter.node.colon, "typeColon")
		end
		return true
	end

	collect.visitExprTable = function(node)
		mark(roles, node.closeBrace, "tableClose")
		local lastEntry = node.entries[#node.entries]
		if lastEntry ~= nil and lastEntry.separator == nil and tokenHasLeadingNewline(node.closeBrace) then
			markLastReplacementItem(trailingCommas, lastEntry.value)
		end

		return true
	end

	collect.visitTypeOptional = function(node)
		mark(roles, node.token, "postfix")
		return true
	end

	collect.visitExprConstantString = function(node)
		table.insert(items, node)
		return false
	end

	collect.visitTypeSingletonString = function(node)
		table.insert(items, node)
		return false
	end

	collect.visitExprInterpString = function(node)
		table.insert(items, node)
		return false
	end

	collect.visitToken = function(node)
		table.insert(items, node)
		return false
	end

	visitor.visitBlock(parseResult.root, collect)
	table.insert(items, parseResult.eof)

	return items
end

local function pushTriviaToken(tokens: { FormatToken }, trivia, pendingNewlines: number): number
	local kind = if trivia.tag == "blockcomment" then "commentBlock" else "commentLine"
	table.insert(tokens, {
		text = trivia.text,
		kind = kind,
		leadingNewlines = pendingNewlines,
	})
	return 0
end

local function pushRawTriviaToken(tokens: { FormatToken }, text: string, pendingNewlines: number): number
	table.insert(tokens, {
		text = text,
		kind = classifyText(text),
		leadingNewlines = pendingNewlines,
	})
	return 0
end

local function buildFormatTokens(parseResult): { FormatToken }
	local tokens: { FormatToken } = {}
	local roles = {}
	local trailingCommas = {}
	local pendingNewlines = 0

	for _, node in collectReplacementItems(parseResult, roles, trailingCommas) do
		for _, trivia in itemLeadingTrivia(node) do
			if trivia.tag == "whitespace" then
				if trivia.text:match("^%s*$") then
					pendingNewlines += countNewlines(trivia.text)
				elseif trivia.text:match("^<<.*>>$") then
					pendingNewlines = pushRawTriviaToken(tokens, trivia.text, pendingNewlines)
				end
			elseif trivia.tag == "comment" or trivia.tag == "blockcomment" then
				pendingNewlines = pushTriviaToken(tokens, trivia, pendingNewlines)
			end
		end

		local text = itemText(node)
		table.insert(tokens, {
			text = text,
			kind = if node.kind == "expr" and (node.tag == "string" or node.tag == "interpolatedstring") then "string"
				elseif node.kind == "type" and node.tag == "string" then "string"
				else classifyText(text),
			leadingNewlines = pendingNewlines,
			node = node,
			role = roles[node],
			trailingCommaAfter = trailingCommas[node],
		})
		pendingNewlines = 0

		for _, trivia in itemTrailingTrivia(node) do
			if trivia.tag == "whitespace" then
				if trivia.text:match("^%s*$") then
					pendingNewlines += countNewlines(trivia.text)
				elseif trivia.text:match("^<<.*>>$") then
					pendingNewlines = pushRawTriviaToken(tokens, trivia.text, pendingNewlines)
				end
			elseif trivia.tag == "comment" or trivia.tag == "blockcomment" then
				pendingNewlines = pushTriviaToken(tokens, trivia, pendingNewlines)
			end
		end
	end

	for index, token in tokens do
		if token.role == "tableClose" and token.leadingNewlines > 0 then
			local previousIndex = index - 1
			while previousIndex > 0 and (tokens[previousIndex].kind == "commentLine" or tokens[previousIndex].kind == "commentBlock") do
				previousIndex -= 1
			end

			local previousToken = tokens[previousIndex]
			if previousToken ~= nil and previousToken.text ~= "{" and previousToken.text ~= "," and previousToken.text ~= ";" then
				previousToken.trailingCommaAfter = true
			end
		end
	end

	for index = 1, #tokens - 1 do
		local token = tokens[index]
		local nextToken = tokens[index + 1]
		if token.kind == "commentLine" and token.leadingNewlines == 0 and nextToken.text == "," then
			nextToken.leadingNewlines = 0
			tokens[index] = nextToken
			tokens[index + 1] = token
		end
	end

	return tokens
end

local function isUnaryContext(previous: FormatToken?): boolean
	if previous == nil then
		return true
	end

	if
		OPENERS[previous.text]
		or previous.text == ","
		or previous.text == "="
		or previous.text == "return"
		or previous.text == "then"
		or previous.text == "else"
		or previous.text == "do"
	then
		return true
	end

	return BINARY_OPERATORS[previous.text] == true and previous.text ~= "and" and previous.text ~= "or"
end

local function needsSpace(previous: FormatToken?, current: FormatToken): boolean
	if previous == nil or current.text == "" then
		return false
	end

	local previousText: string = previous.text
	local currentText: string = current.text
	local previousIsGenericClose = previous.role == "genericClose"
		or (previous.role == "functionReturnAnnotationEnd" and previousText == ">")
	local currentIsGenericClose = current.role == "genericClose"
		or (current.role == "functionReturnAnnotationEnd" and currentText == ">")

	if previous.kind == "commentBlock" and CLOSERS[currentText] then
		return false
	end

	if current.kind == "commentLine" then
		return true
	end

	if current.kind == "commentBlock" then
		return true
	end

	if previous.kind == "commentLine" or previous.kind == "commentBlock" then
		return true
	end

	if current.role == "typeColon" then
		return false
	end

	if current.role == "postfix" then
		return false
	end

	if previousText:sub(1, 1) == "@" and currentText:sub(1, 1) == "@" then
		return false
	end

	if currentText == "::" or previousText == "::" then
		return true
	end

	if previous.role == "typeColon" then
		return true
	end

	if previousText == "->" and currentText == "(" then
		return true
	end

	if previousText == "read" and currentText == "[" then
		return true
	end

	if previousText == "=" and current.role == "genericOpen" then
		return true
	end

	if current.role == "genericOpen" or currentIsGenericClose then
		return false
	end

	if previous.role == "genericOpen" then
		return false
	end

	if previousIsGenericClose and (currentIsGenericClose or currentText == "(") then
		return false
	end

	if textEquals(previousText, ",") or textEquals(previousText, ";") then
		return true
	end

	if textEquals(currentText, "}") and not textEquals(previousText, "{") and current.leadingNewlines == 0 then
		return true
	end

	if textEquals(currentText, ",") or textEquals(currentText, ";") or CLOSERS[currentText] then
		return false
	end

	if textEquals(previousText, ".") or textEquals(currentText, ".") then
		return false
	end

	if textEquals(previousText, ":") or textEquals(currentText, ":") then
		return false
	end

	if textEquals(currentText, "-") and isUnaryContext(previous) then
		return BINARY_OPERATORS[previousText] == true or previous.kind == "keyword"
	end

	if textEquals(previousText, "-") and previous.unary then
		return false
	end

	if textEquals(currentText, "(") then
		if previousText == "function" then
			return false
		end

		if previousText == "if" or previousText == "elseif" or previousText == "while" or previousText == "for" or previousText == "until" then
			return true
		end

		if
			BINARY_OPERATORS[previousText]
			or previousText == "return"
			or previousText == "then"
			or previousText == "else"
			or previousText == "do"
			or previousText == "not"
		then
			return true
		end

		return false
	end

	if textEquals(previousText, "(") or textEquals(previousText, "[") then
		return false
	end

	if textEquals(previousText, "{") and not textEquals(currentText, "}") then
		return true
	end

	if textEquals(currentText, "#") then
		return true
	end

	if textEquals(previousText, "#") then
		return false
	end

	if BINARY_OPERATORS[previousText] or BINARY_OPERATORS[currentText] then
		return true
	end

	if textEquals(previousText, "not") then
		return true
	end

	if previous.kind == "keyword" or current.kind == "keyword" then
		return true
	end

	if
		(previous.kind == "identifier" or previous.kind == "number" or previous.kind == "string")
		and (current.kind == "identifier" or current.kind == "number" or current.kind == "string")
	then
		return true
	end

	return false
end

local function startsBlock(token: FormatToken): boolean
	return token.text == "then" or token.text == "do" or token.text == "repeat"
end

local function isMiddleBlockToken(token: FormatToken): boolean
	return token.text == "else" or token.text == "elseif"
end

local function isClosingBlockToken(token: FormatToken): boolean
	return token.text == "end" or token.text == "until"
end

local function shouldBreakBefore(previous: FormatToken?, current: FormatToken): boolean
	if previous == nil or current.text == "" then
		return false
	end

	if current.text == "end" and previous.role == "functionParamsClose" and not previous.multilineClose then
		return false
	end

	if current.text == "function" and previous.text == "}" then
		return true
	end

	if current.text:sub(1, 1) == "@" and previous.text:sub(1, 1) == "@" then
		return true
	end

	if current.leadingNewlines > 0 then
		return true
	end

	if current.role ~= "ifExpressionKeyword" and (isMiddleBlockToken(current) or isClosingBlockToken(current)) then
		return true
	end

	return false
end

local function shouldBreakAfter(current: FormatToken, nextToken: FormatToken?): (boolean, number?)
	if current.kind == "commentLine" then
		return true
	end

	if
		current.role ~= "ifExpressionKeyword"
		and (startsBlock(current) or current.text == "else")
		and not (nextToken ~= nil and nextToken.kind == "commentLine" and nextToken.leadingNewlines == 0)
	then
		return nextToken ~= nil and not isClosingBlockToken(nextToken) and not isMiddleBlockToken(nextToken)
	end

	if current.text == ";" then
		return true
	end

	return false
end

local function buildReplacements(parseResult): { [any]: Replacement }
	local tokens = buildFormatTokens(parseResult)
	local replacements: { [any]: Replacement } = {}
	local pending = ""
	local line = ""
	local indent = 0
	local parenDepth = 0
	local blockDepth = 0
	local awaitingFunctionParams = false
	local functionParamDepths: { number } = {}
	local functionBodyStack: { { targetDepth: number, endIndent: number, restoreIndent: number } } = {}
	local parenIndentDepths: { { depth: number, endIndent: number, restoreIndent: number } } = {}
	local braceIndentStack: { { endIndent: number, restoreIndent: number } } = {}
	local previous: FormatToken? = nil

	local function indentation(): string
		return string.rep(INDENT, math.max(indent, 0))
	end

	local function lineIndentLevel(): number
		local whitespace = line:match("^\t*") or ""
		return #whitespace
	end

	local function startFunctionBody()
		local endIndent = lineIndentLevel()
		table.insert(functionBodyStack, {
			targetDepth = blockDepth + 1,
			endIndent = endIndent,
			restoreIndent = indent,
		})
		blockDepth += 1
		indent = endIndent + 1
	end

	local function isContinuationOperator(token: FormatToken): boolean
		if token.unary or not BINARY_OPERATORS[token.text] then
			return false
		end

		return token.role ~= "genericClose" and token.role ~= "functionReturnAnnotationEnd"
	end

	local function appendText(text: string)
		pending ..= text

		local newlineCount = countNewlines(text)
		if newlineCount > 0 then
			local lastNewline = text:match("^.*()\n")
			line = if lastNewline == nil then "" else text:sub(lastNewline + 1)
		else
			line ..= text
		end
	end

	local function newline(count: number?)
		if line == "" and pending:sub(-1) == "\n" and (count or 1) <= 1 then
			return
		end

		if line == "" and pending == "" then
			return
		end

		appendText("\n")

		local blanks = math.min(math.max((count or 1) - 1, 0), MAX_BLANK_LINES)
		for _ = 1, blanks do
			appendText("\n")
		end
	end

	local function writeSpace()
		if line == "" then
			appendText(indentation())
		elseif not line:match("[ \t]$") then
			appendText(" ")
		end
	end

	local function writePlain(text: string)
		if line == "" then
			appendText(indentation())
		end
		appendText(text)
	end

	local function writeNode(token: FormatToken)
		if token.text == "" then
			if line ~= "" then
				newline(1)
			end
			replacements[token.node] = { content = pending, preserveTrivia = false }
			pending = ""
			return
		end

		if line == "" then
			appendText(indentation())
		end

		local content = pending .. token.text
		replacements[token.node] = { content = content, preserveTrivia = false }
		pending = ""
		line ..= token.text
	end

	for index, token in tokens do
		local nextToken = tokens[index + 1]
		local afterNextToken = tokens[index + 2]
		local openedFunctionBody = false
		local parenClose = if token.text == ")" then parenIndentDepths[#parenIndentDepths] else nil
		if parenClose ~= nil and (parenClose.depth ~= parenDepth or (token.leadingNewlines == 0 and not token.multilineClose)) then
			parenClose = nil
		end
		local braceClose = if token.text == "}" and (token.leadingNewlines > 0 or token.multilineClose)
			then braceIndentStack[#braceIndentStack]
			else nil
		local functionBodyEnd = if token.role == "functionEnd" then functionBodyStack[#functionBodyStack] else nil
		local closesInlineEmptyFunction = token.text == "end"
			and previous ~= nil
			and previous.role == "functionParamsClose"
			and not previous.multilineClose
		if closesInlineEmptyFunction then
			functionBodyEnd = nil
		end

		if token.text == "-" and isUnaryContext(previous) then
			token.unary = true
		end

		if
			(isClosingBlockToken(token) or isMiddleBlockToken(token))
			and token.role ~= "ifExpressionKeyword"
			and not closesInlineEmptyFunction
			and not token.dedentedBefore
			and (line == "" or shouldBreakBefore(previous, token))
		then
			if functionBodyEnd ~= nil then
				indent = functionBodyEnd.endIndent
			else
				indent = math.max(indent - 1, 0)
			end
		end

		if parenClose ~= nil then
			indent = parenClose.endIndent
			token.multilineClose = true
		end

		if braceClose ~= nil then
			indent = braceClose.endIndent
			token.multilineClose = true
		end

		if ((token.text == "}" and braceClose == nil) or token.text == "]" or token.role == "genericClose") and token.leadingNewlines > 0 then
			indent = math.max(indent - 1, 0)
		end

		if token.kind == "commentLine" and nextToken ~= nil and isMiddleBlockToken(nextToken) then
			indent = math.max(indent - 1, 0)
			nextToken.dedentedBefore = true
		end

		if line == "" and previous ~= nil and previous.kind == "commentLine" and (token.text == "." or token.text == ":") then
			appendText(indentation() .. INDENT)
		elseif
			line == ""
			and previous ~= nil
			and previous.kind == "commentLine"
			and (token.text == "and" or token.text == "or" or (BINARY_OPERATORS[token.text] and not token.unary))
		then
			appendText(indentation() .. INDENT)
		elseif shouldBreakBefore(previous, token) then
			local previousLineIndent = lineIndentLevel()
			local previousLine = line
			newline(token.leadingNewlines)
			if line == "" and token.role == "ifExpressionKeyword" then
				local keywordIndent = if token.text == "then"
					or (
						token.text == "elseif"
						and previousLine:find("%f[%w]then%f[%W]") ~= nil
						and previousLine:match("^%s*then%f[%W]") == nil
					)
						then previousLineIndent + 1
						else previousLineIndent
				appendText(string.rep(INDENT, keywordIndent))
			elseif line == "" and previous ~= nil and previous.role == "ifExpressionKeyword" then
				appendText(string.rep(INDENT, previousLineIndent + 1))
			elseif line == "" and token.text == "then" and previous ~= nil and previous.kind == "commentLine" then
				appendText(string.rep(INDENT, previousLineIndent + 1))
			elseif
				line == ""
				and previous ~= nil
				and (previous.text == "if" or previous.text == "elseif" or previous.text == "while" or previous.text == "until")
			then
				appendText(indentation() .. INDENT)
			elseif line == "" and (token.text == "." or token.text == ":") and previous ~= nil then
				appendText(indentation() .. INDENT)
			elseif line == "" and (token.text == "and" or token.text == "or" or (BINARY_OPERATORS[token.text] and not token.unary)) and previous ~= nil then
				local continuationIndent = if #parenIndentDepths > 0 and (token.text == "and" or token.text == "or")
					then ""
					else INDENT
				appendText(indentation() .. continuationIndent)
			elseif line == "" and previous ~= nil and isContinuationOperator(previous) then
				appendText(indentation() .. INDENT)
			end
		elseif needsSpace(previous, token) then
			writeSpace()
		end

		if token.node == nil then
			writePlain(token.text)
		else
			writeNode(token)
		end

		if token.trailingCommaAfter then
			appendText(",")
		end

		if
			token.role == "functionReturnAnnotationEnd"
			and nextToken ~= nil
			and nextToken.text ~= "end"
			and not (nextToken.kind == "commentLine" and nextToken.leadingNewlines == 0)
		then
			startFunctionBody()
			newline(nextToken.leadingNewlines)
			nextToken.leadingNewlines = 0
			nextToken.functionBodyStartedBefore = true
		end

		if
			token.kind == "commentLine"
			and previous ~= nil
			and (previous.role == "functionParamsClose" or previous.role == "functionReturnAnnotationEnd")
			and token.leadingNewlines == 0
			and not token.functionBodyStartedBefore
		then
			startFunctionBody()
		end

		if token.text == "function" then
			awaitingFunctionParams = true
		elseif token.text == "(" then
			parenDepth += 1
			if awaitingFunctionParams then
				table.insert(functionParamDepths, parenDepth)
				awaitingFunctionParams = false
			end
			if nextToken ~= nil and nextToken.leadingNewlines > 0 then
				local endIndent = lineIndentLevel()
				table.insert(parenIndentDepths, {
					depth = parenDepth,
					endIndent = endIndent,
					restoreIndent = indent,
				})
				indent = endIndent + 1
			end
		elseif token.text == ")" then
			local functionParamDepth = functionParamDepths[#functionParamDepths]
			local closesFunctionParams = functionParamDepth ~= nil and functionParamDepth == parenDepth
			parenDepth = math.max(parenDepth - 1, 0)

			if closesFunctionParams then
				table.remove(functionParamDepths)
				if
					nextToken ~= nil
					and nextToken.text ~= ":"
					and nextToken.text ~= "end"
					and not (nextToken.kind == "commentLine" and nextToken.leadingNewlines == 0)
				then
					startFunctionBody()
					openedFunctionBody = true
					newline(nextToken.leadingNewlines)
					nextToken.leadingNewlines = 0
					nextToken.functionBodyStartedBefore = true
				end
			end
		end

		local opensMultilineBrace = nextToken ~= nil
			and (
				nextToken.leadingNewlines > 0
				or (
					nextToken.kind == "commentLine"
					and nextToken.leadingNewlines == 0
					and afterNextToken ~= nil
					and afterNextToken.leadingNewlines > 0
				)
			)
		if token.text == "{" and opensMultilineBrace then
			local endIndent = lineIndentLevel()
			table.insert(braceIndentStack, {
				endIndent = endIndent,
				restoreIndent = indent,
			})
			indent = endIndent + 1
		elseif token.role == "genericOpen" and nextToken ~= nil and nextToken.leadingNewlines > 0 then
			indent += 1
		elseif token.role ~= "ifExpressionKeyword" and startsBlock(token) then
			blockDepth += 1
			indent += 1
		elseif token.role ~= "ifExpressionKeyword" and token.text == "else" then
			indent += 1
		end

		local breakAfter, breakNewlines = shouldBreakAfter(token, nextToken)
		if breakAfter then
			local breakLineIndent = lineIndentLevel()
			if
				token.kind == "commentLine"
				and nextToken ~= nil
				and (
					nextToken.role == "genericClose"
					or nextToken.role == "tableClose"
					or (nextToken.text == ")" and parenIndentDepths[#parenIndentDepths] ~= nil and parenIndentDepths[#parenIndentDepths].depth == parenDepth)
				)
			then
				if nextToken.text == ")" and parenIndentDepths[#parenIndentDepths] ~= nil then
					indent = parenIndentDepths[#parenIndentDepths].endIndent
					nextToken.multilineClose = true
				elseif nextToken.role == "tableClose" and braceIndentStack[#braceIndentStack] ~= nil then
					indent = braceIndentStack[#braceIndentStack].endIndent
					nextToken.multilineClose = true
				else
					indent = math.max(indent - 1, 0)
				end
			end
			newline(breakNewlines or (nextToken and nextToken.leadingNewlines or 1))
			if token.kind == "commentLine" and nextToken ~= nil and nextToken.text == "then" and line == "" then
				appendText(string.rep(INDENT, breakLineIndent + 1))
			end
			if nextToken then
				nextToken.leadingNewlines = 0
			end
		elseif token.kind == "commentBlock" and countNewlines(token.text) > 0 then
			newline(nextToken and nextToken.leadingNewlines or 1)
			if nextToken then
				nextToken.leadingNewlines = 0
			end
		end

		if token.text == "end" and functionBodyEnd ~= nil then
			table.remove(functionBodyStack)
			indent = functionBodyEnd.restoreIndent
			blockDepth = math.max(blockDepth - 1, 0)
		elseif braceClose ~= nil then
			table.remove(braceIndentStack)
			indent = braceClose.restoreIndent
		elseif parenClose ~= nil then
			table.remove(parenIndentDepths)
			if not openedFunctionBody then
				indent = parenClose.restoreIndent
			end
		elseif isClosingBlockToken(token) and token.role ~= "ifExpressionKeyword" and not closesInlineEmptyFunction then
			blockDepth = math.max(blockDepth - 1, 0)
		end

		previous = token
	end

	return replacements
end

function format.formatCode(source: string): string
	local parseResult = parser.parse(source)
	local replacements = buildReplacements(parseResult)
	local output = printer.printFile(parseResult, replacements)

	parser.parse(output)

	return output
end

function format.formatParsed(parseResult): string
	local replacements = buildReplacements(parseResult)
	local output = printer.printFile(parseResult, replacements)

	parser.parse(output)

	return output
end

return table.freeze(format)
