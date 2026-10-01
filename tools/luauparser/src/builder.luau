--!strict
-- Token / trivia / span construction, ported from lute/syntax/src/parser.cpp
-- (the AstSerialize visitor). Tokens are emitted in source order; the trivia
-- between consecutive tokens is reconstructed from source slices and split into
-- (trailing-of-previous, leading-of-next) at the first newline.

local lexermod = require("./lexer")

type Position = lexermod.Position
type Location = lexermod.Location

export type Trivia = {
	tag: "whitespace" | "comment" | "blockcomment",
	location: any,
	text: string,
}

export type Token = {
	kind: "token",
	leadingTrivia: { Trivia },
	location: any,
	text: string,
	trailingTrivia: { Trivia },
	tag: string?,
}

export type CommentInfo = { kind: "comment" | "blockcomment", location: Location }

export type Builder = {
	source: string,
	lineOffsets: { number }, -- 1-indexed: lineOffsets[line+1] = byte offset of line start
	currentPosition: Position,
	comments: { CommentInfo },
	commentCursor: number,
	lastToken: Token?,
}

local Builder = {}
Builder.__index = Builder

local function computeLineOffsets(content: string): { number }
	local result = { 0 }
	local i = 0
	local n = #content
	while i < n do
		local ch = string.byte(content, i + 1)
		if ch == 13 or ch == 10 then -- '\r' or '\n'
			if ch == 13 and i + 1 < n and string.byte(content, i + 2) == 10 then
				i += 1
			end
			table.insert(result, i + 1)
		end
		i += 1
	end
	return result
end

local function new(source: string, comments: { CommentInfo }): Builder
	return setmetatable({
		source = source,
		lineOffsets = computeLineOffsets(source),
		currentPosition = { line = 0, column = 0 },
		comments = comments,
		commentCursor = 1,
		lastToken = nil,
	}, Builder) :: any
end

-- Span serialization (1-based line/column), matching parser.cpp serialize(Location).
local function span(location: Location): any
	return {
		beginLine = location.begin.line + 1,
		beginColumn = location.begin.column + 1,
		endLine = location.endPos.line + 1,
		endColumn = location.endPos.column + 1,
	}
end

local function offsetOf(self: Builder, p: Position): number
	return self.lineOffsets[p.line + 1] + p.column
end

local function posLess(a: Position, b: Position): boolean
	if a.line == b.line then
		return a.column < b.column
	end
	return a.line < b.line
end

local function posEq(a: Position, b: Position): boolean
	return a.line == b.line and a.column == b.column
end

function Builder.advancePosition(self: Builder, contents: string)
	if contents == "" then
		return
	end
	local index = 0
	local numLines = 0
	while true do
		local nl = string.find(contents, "\n", index + 1, true)
		if not nl then
			break
		end
		numLines += 1
		index = nl -- nl is 1-based position of '\n'; next search starts after it
	end
	self.currentPosition.line += numLines
	if numLines > 0 then
		self.currentPosition.column = #contents - index
	else
		self.currentPosition.column += #contents
	end
end

function Builder.extractWhitespace(self: Builder, newPos: Position): { Trivia }
	local beginPosition = { line = self.currentPosition.line, column = self.currentPosition.column }
	local startOffset = offsetOf(self, self.currentPosition)
	local endOffset = offsetOf(self, newPos)
	local trivia = string.sub(self.source, startOffset + 1, endOffset)

	local result: { Trivia } = {}
	while trivia ~= "" do
		local nl = string.find(trivia, "\n", 1, true)
		local part: string
		if not nl then
			part = trivia
			trivia = ""
		else
			part = string.sub(trivia, 1, nl)
			trivia = string.sub(trivia, nl + 1)
		end
		self:advancePosition(part)
		table.insert(result, {
			tag = "whitespace",
			location = span({
				begin = beginPosition,
				endPos = { line = self.currentPosition.line, column = self.currentPosition.column },
			}),
			text = part,
		})
		beginPosition = { line = self.currentPosition.line, column = self.currentPosition.column }
	end
	return result
end

function Builder.extractTrivia(self: Builder, newPos: Position): { Trivia }
	if posEq(self.currentPosition, newPos) then
		return {}
	end
	local result: { Trivia } = {}

	-- Comments whose location is enclosed by [currentPosition, newPos].
	while self.commentCursor <= #self.comments do
		local comment = self.comments[self.commentCursor]
		local cl = comment.location
		-- encloses: currentPosition <= begin and newPos >= end
		local enclosed = not posLess(cl.begin, self.currentPosition)
			and not posLess(newPos, cl.endPos)
		if not enclosed then
			break
		end
		self.commentCursor += 1

		if posLess(self.currentPosition, cl.begin) then
			local ws = self:extractWhitespace(cl.begin)
			table.move(ws, 1, #ws, #result + 1, result)
		end

		local startOffset = offsetOf(self, cl.begin)
		local endOffset = offsetOf(self, cl.endPos)
		local commentText = string.sub(self.source, startOffset + 1, endOffset)
		self:advancePosition(commentText)
		table.insert(result, {
			tag = comment.kind,
			location = span(cl),
			text = commentText,
		})
	end

	if posLess(self.currentPosition, newPos) then
		local ws = self:extractWhitespace(newPos)
		table.move(ws, 1, #ws, #result + 1, result)
	end

	return result
end

-- Splits trivia into (trailing, leading): trailing is everything up to and
-- including the first whitespace containing a newline.
local function splitTrivia(trivia: { Trivia }): ({ Trivia }, { Trivia })
	local i = 1
	while i <= #trivia do
		if trivia[i].tag == "whitespace" and string.find(trivia[i].text, "\n", 1, true) then
			break
		end
		i += 1
	end
	if i > #trivia then
		return trivia, {}
	end
	local trailing: { Trivia } = {}
	local leading: { Trivia } = {}
	for j = 1, i do
		table.insert(trailing, trivia[j])
	end
	for j = i + 1, #trivia do
		table.insert(leading, trivia[j])
	end
	return trailing, leading
end

-- Fills a token placeholder (`{ _pos = Position, text = string }`) in place,
-- reconstructing trivia relative to the previous token. Placeholders are filled
-- in source order (the parser sorts them by position before calling this).
function Builder.fill(self: Builder, tok: any)
	local position: Position = tok._pos
	local text: string = tok.text

	local trivia = self:extractTrivia(position)
	local leadingTrivia: { Trivia }
	if self.lastToken then
		local trailing, leading = splitTrivia(trivia)
		self.lastToken.trailingTrivia = trailing
		leadingTrivia = leading
	else
		leadingTrivia = trivia
	end

	local textLength = #text
	local endPosition = { line = position.line, column = position.column + textLength }

	local forceEnd: Position? = tok._forceEnd

	tok._pos = nil
	tok._forceEnd = nil
	tok.kind = "token"
	tok.leadingTrivia = leadingTrivia
	tok.location = span({ begin = position, endPos = endPosition })
	tok.trailingTrivia = {}

	local interpAdjust: boolean? = tok._interpAdjust
	tok._interpAdjust = nil

	self:advancePosition(text)
	if forceEnd then
		self.currentPosition = { line = forceEnd.line, column = forceEnd.column }
	elseif interpAdjust then
		-- Interpolated-string parts carry delimiter chars (`, { or }) not in the
		-- emitted text: +2 columns if single-line, +1 if the part spanned lines.
		if position.line == self.currentPosition.line then
			self.currentPosition.column += 2
		else
			self.currentPosition.column += 1
		end
	end
	self.lastToken = tok
end

-- Some tokens (strings) contain quotes that are not part of the emitted text;
-- after filling them the caller forces currentPosition to the node's true end.
function Builder.setPosition(self: Builder, p: Position)
	self.currentPosition = { line = p.line, column = p.column }
end

return {
	new = new,
	span = span,
	computeLineOffsets = computeLineOffsets,
}
