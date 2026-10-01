--!strict
-- Pure-Luau port of Luau's Ast/src/Lexer.cpp.
--
-- Positions are 0-based (line, column) exactly as in Luau internals; the CST
-- serializer converts to 1-based. `offset` is a 0-based index into the source
-- byte buffer.

export type Position = { line: number, column: number }
export type Location = { begin: Position, endPos: Position }

-- Lexeme type constants. Single-character tokens use their byte value (< 256,
-- matching Luau where `type` is the char code). Everything else uses the named
-- values below, which start past 256 so they can never collide with a char.
local T = {
	Eof = 0,

	Equal = 257,
	LessEqual = 258,
	GreaterEqual = 259,
	NotEqual = 260,
	Dot2 = 261,
	Dot3 = 262,
	SkinnyArrow = 263,
	DoubleColon = 264,
	FloorDiv = 265,

	InterpStringBegin = 266,
	InterpStringMid = 267,
	InterpStringEnd = 268,
	InterpStringSimple = 269,

	AddAssign = 270,
	SubAssign = 271,
	MulAssign = 272,
	DivAssign = 273,
	FloorDivAssign = 274,
	ModAssign = 275,
	PowAssign = 276,
	ConcatAssign = 277,

	RawString = 278,
	QuotedString = 279,
	Number = 280,
	Name = 281,

	Comment = 282,
	BlockComment = 283,

	Attribute = 284,
	AttributeOpen = 285,

	BrokenString = 286,
	BrokenComment = 287,
	BrokenUnicode = 288,
	BrokenInterpDoubleBrace = 289,
	Error = 290,

	-- Reserved words.
	ReservedAnd = 291,
	ReservedBreak = 292,
	ReservedDo = 293,
	ReservedElse = 294,
	ReservedElseif = 295,
	ReservedEnd = 296,
	ReservedFalse = 297,
	ReservedFor = 298,
	ReservedFunction = 299,
	ReservedIf = 300,
	ReservedIn = 301,
	ReservedLocal = 302,
	ReservedNil = 303,
	ReservedNot = 304,
	ReservedOr = 305,
	ReservedRepeat = 306,
	ReservedReturn = 307,
	ReservedThen = 308,
	ReservedTrue = 309,
	ReservedUntil = 310,
	ReservedWhile = 311,
}

local reservedWords: { [string]: number } = {
	["and"] = T.ReservedAnd,
	["break"] = T.ReservedBreak,
	["do"] = T.ReservedDo,
	["else"] = T.ReservedElse,
	["elseif"] = T.ReservedElseif,
	["end"] = T.ReservedEnd,
	["false"] = T.ReservedFalse,
	["for"] = T.ReservedFor,
	["function"] = T.ReservedFunction,
	["if"] = T.ReservedIf,
	["in"] = T.ReservedIn,
	["local"] = T.ReservedLocal,
	["nil"] = T.ReservedNil,
	["not"] = T.ReservedNot,
	["or"] = T.ReservedOr,
	["repeat"] = T.ReservedRepeat,
	["return"] = T.ReservedReturn,
	["then"] = T.ReservedThen,
	["true"] = T.ReservedTrue,
	["until"] = T.ReservedUntil,
	["while"] = T.ReservedWhile,
}

export type Lexeme = {
	type: number,
	location: Location,
	-- For Name/Attribute/reserved: the identifier text. For string/number/
	-- comment: the data slice. Otherwise nil.
	data: string?,
	codepoint: number?,
}

export type Lexer = {
	source: string,
	bufferSize: number,
	offset: number,
	line: number,
	lineOffset: number,
	lexeme: Lexeme,
	prevLocation: Location,
	braceStack: { string }, -- "normal" | "interp"
	skipComments: boolean,
	readNames: boolean,
}

local Lexer = {}
Lexer.__index = Lexer

local function pos(line: number, column: number): Position
	return { line = line, column = column }
end

local function loc(b: Position, e: Position): Location
	return { begin = b, endPos = e }
end

-- Character classification (ASCII, byte-based).
local function isAlpha(b: number): boolean
	-- (ch | ' ') - 'a' < 26
	local lower = bit32.bor(b, 0x20)
	return lower >= 97 and lower <= 122
end

local function isDigit(b: number): boolean
	return b >= 48 and b <= 57
end

local function isHexDigit(b: number): boolean
	if b >= 48 and b <= 57 then
		return true
	end
	local lower = bit32.bor(b, 0x20)
	return lower >= 97 and lower <= 102
end

local function isSpace(b: number): boolean
	return b == 32 or b == 9 or b == 13 or b == 10 or b == 11 or b == 12
end

local function isNewline(b: number): boolean
	return b == 10 -- '\n'
end

local function new(source: string, startLine: number?, startColumn: number?): Lexer
	local sl = startLine or 0
	local sc = startColumn or 0
	local self: Lexer = setmetatable({
		source = source,
		bufferSize = #source,
		offset = 0,
		line = sl,
		-- lineOffset = 0 - startColumn (unsigned wrap in C++, but we keep it as a
		-- plain number; column is computed as offset - lineOffset).
		lineOffset = -sc,
		lexeme = { type = T.Eof, location = loc(pos(sl, sc), pos(sl, sc)) },
		prevLocation = loc(pos(0, 0), pos(0, 0)),
		braceStack = {},
		skipComments = false,
		readNames = true,
	}, Lexer) :: any
	return self
end

-- Byte at offset (0-based) + lookahead; 0 past end.
function Lexer.peekch(self: Lexer, lookahead: number?): number
	local idx = self.offset + (lookahead or 0)
	if idx < self.bufferSize then
		return string.byte(self.source, idx + 1)
	end
	return 0
end

function Lexer.position(self: Lexer): Position
	return pos(self.line, self.offset - self.lineOffset)
end

function Lexer.consume(self: Lexer)
	self.offset += 1
end

function Lexer.consumeAny(self: Lexer)
	if isNewline(string.byte(self.source, self.offset + 1) or 0) then
		self.line += 1
		self.lineOffset = self.offset + 1
	end
	self.offset += 1
end

function Lexer.setSkipComments(self: Lexer, skip: boolean)
	self.skipComments = skip
end

function Lexer.setReadNames(self: Lexer, read: boolean)
	self.readNames = read
end

-- Returns number of '=' signs between brackets, or negative for non/malformed
-- separators. Does not consume the closing brace.
function Lexer.skipLongSeparator(self: Lexer): number
	local start = self:peekch()
	self:consume()
	local count = 0
	while self:peekch() == 61 do -- '='
		self:consume()
		count += 1
	end
	if start == self:peekch() then
		return count
	else
		return (-count) - 1
	end
end

function Lexer.readLongString(self: Lexer, start: Position, sep: number, ok: number, broken: number): Lexeme
	-- skip (second) [
	self:consume()
	local startOffset = self.offset
	while self:peekch() ~= 0 do
		if self:peekch() == 93 then -- ']'
			if self:skipLongSeparator() == sep then
				self:consume() -- skip (second) ]
				local endOffset = self.offset - sep - 2
				return {
					type = ok,
					location = loc(start, self:position()),
					data = string.sub(self.source, startOffset + 1, endOffset),
				}
			end
		else
			self:consumeAny()
		end
	end
	return { type = broken, location = loc(start, self:position()) }
end

function Lexer.readCommentBody(self: Lexer): Lexeme
	local start = self:position()
	self:consume()
	self:consume()
	local startOffset = self.offset
	if self:peekch() == 91 then -- '['
		local sep = self:skipLongSeparator()
		if sep >= 0 then
			return self:readLongString(start, sep, T.BlockComment, T.BrokenComment)
		end
	end
	while true do
		local c = self:peekch()
		if c == 0 or c == 13 or isNewline(c) then
			break
		end
		self:consume()
	end
	return {
		type = T.Comment,
		location = loc(start, self:position()),
		data = string.sub(self.source, startOffset + 1, self.offset),
	}
end

function Lexer.readBackslashInString(self: Lexer)
	self:consume()
	local c = self:peekch()
	if c == 13 then -- '\r'
		self:consume()
		if self:peekch() == 10 then
			self:consumeAny()
		end
	elseif c == 0 then
		-- nothing
	elseif c == 122 then -- 'z'
		self:consume()
		while isSpace(self:peekch()) do
			self:consumeAny()
		end
	else
		self:consumeAny()
	end
end

function Lexer.readQuotedString(self: Lexer): Lexeme
	local start = self:position()
	local delimiter = self:peekch()
	self:consume()
	local startOffset = self.offset
	while self:peekch() ~= delimiter do
		local c = self:peekch()
		if c == 0 or c == 13 or c == 10 then
			return { type = T.BrokenString, location = loc(start, self:position()) }
		elseif c == 92 then -- '\\'
			self:readBackslashInString()
		else
			self:consume()
		end
	end
	self:consume()
	return {
		type = T.QuotedString,
		location = loc(start, self:position()),
		data = string.sub(self.source, startOffset + 1, self.offset - 1),
	}
end

function Lexer.readInterpolatedStringSection(self: Lexer, start: Position, formatType: number, endType: number): Lexeme
	local startOffset = self.offset
	while self:peekch() ~= 96 do -- '`'
		local c = self:peekch()
		if c == 0 or c == 13 or c == 10 then
			return { type = T.BrokenString, location = loc(start, self:position()) }
		elseif c == 92 then -- '\\'
			if self:peekch(1) == 117 and self:peekch(2) == 123 then -- 'u' '{'
				self:consume()
				self:consume()
				self:consume()
			else
				self:readBackslashInString()
			end
		elseif c == 123 then -- '{'
			table.insert(self.braceStack, "interp")
			if self:peekch(1) == 123 then
				local brokenDoubleBrace: Lexeme = {
					type = T.BrokenInterpDoubleBrace,
					location = loc(start, self:position()),
					data = string.sub(self.source, startOffset + 1, self.offset),
				}
				self:consume()
				self:consume()
				return brokenDoubleBrace
			end
			self:consume()
			return {
				type = formatType,
				location = loc(start, self:position()),
				data = string.sub(self.source, startOffset + 1, self.offset - 1),
			}
		else
			self:consume()
		end
	end
	self:consume()
	return {
		type = endType,
		location = loc(start, self:position()),
		data = string.sub(self.source, startOffset + 1, self.offset - 1),
	}
end

function Lexer.readInterpolatedStringBegin(self: Lexer): Lexeme
	local start = self:position()
	self:consume()
	return self:readInterpolatedStringSection(start, T.InterpStringBegin, T.InterpStringSimple)
end

function Lexer.readNumber(self: Lexer, start: Position, startOffset: number): Lexeme
	repeat
		self:consume()
		local c = self:peekch()
	until not (isDigit(c) or c == 46 or c == 95) -- '.' '_'

	if self:peekch() == 101 or self:peekch() == 69 then -- 'e' 'E'
		self:consume()
		if self:peekch() == 43 or self:peekch() == 45 then -- '+' '-'
			self:consume()
		end
	end

	while true do
		local c = self:peekch()
		if isAlpha(c) or isDigit(c) or c == 95 then
			self:consume()
		else
			break
		end
	end

	return {
		type = T.Number,
		location = loc(start, self:position()),
		data = string.sub(self.source, startOffset + 1, self.offset),
	}
end

-- Returns (name, type). type is Name/Attribute/reserved.
function Lexer.readName(self: Lexer): (string, number)
	local startOffset = self.offset
	repeat
		self:consume()
		local c = self:peekch()
	until not (isAlpha(c) or isDigit(c) or c == 95)
	local name = string.sub(self.source, startOffset + 1, self.offset)
	if string.byte(name, 1) == 64 then -- '@'
		return name, T.Attribute
	end
	local reserved = reservedWords[name]
	if reserved then
		return name, reserved
	end
	return name, T.Name
end

function Lexer.readUtf8Error(self: Lexer): Lexeme
	local start = self:position()
	local codepoint = 0
	local size = 0
	local b = self:peekch()
	if bit32.band(b, 0x80) == 0 then
		size = 1
		codepoint = bit32.band(b, 0x7F)
	elseif bit32.band(b, 0xE0) == 0xC0 then
		size = 2
		codepoint = bit32.band(b, 0x1F)
	elseif bit32.band(b, 0xF0) == 0xE0 then
		size = 3
		codepoint = bit32.band(b, 0x0F)
	elseif bit32.band(b, 0xF8) == 0xF0 then
		size = 4
		codepoint = bit32.band(b, 0x07)
	else
		self:consume()
		return { type = T.BrokenUnicode, location = loc(start, self:position()), codepoint = 0 }
	end
	self:consume()
	for _ = 1, size - 1 do
		if bit32.band(self:peekch(), 0xC0) ~= 0x80 then
			return { type = T.BrokenUnicode, location = loc(start, self:position()), codepoint = 0 }
		end
		codepoint = bit32.lshift(codepoint, 6)
		codepoint = bit32.bor(codepoint, bit32.band(self:peekch(), 0x3F))
		self:consume()
	end
	return { type = T.BrokenUnicode, location = loc(start, self:position()), codepoint = codepoint }
end

function Lexer.readNext(self: Lexer): Lexeme
	local start = self:position()
	local c = self:peekch()

	if c == 0 then
		return { type = T.Eof, location = loc(start, start) }
	elseif c == 45 then -- '-'
		if self:peekch(1) == 62 then -- '>'
			self:consume()
			self:consume()
			return { type = T.SkinnyArrow, location = loc(start, pos(start.line, start.column + 2)) }
		elseif self:peekch(1) == 61 then -- '='
			self:consume()
			self:consume()
			return { type = T.SubAssign, location = loc(start, pos(start.line, start.column + 2)) }
		elseif self:peekch(1) == 45 then -- '-'
			return self:readCommentBody()
		else
			self:consume()
			return { type = 45, location = loc(start, pos(start.line, start.column + 1)) }
		end
	elseif c == 91 then -- '['
		local sep = self:skipLongSeparator()
		if sep >= 0 then
			return self:readLongString(start, sep, T.RawString, T.BrokenString)
		elseif sep == -1 then
			return { type = 91, location = loc(start, pos(start.line, start.column + 1)) }
		else
			return { type = T.BrokenString, location = loc(start, self:position()) }
		end
	elseif c == 123 then -- '{'
		self:consume()
		if #self.braceStack > 0 then
			table.insert(self.braceStack, "normal")
		end
		return { type = 123, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 125 then -- '}'
		self:consume()
		if #self.braceStack == 0 then
			return { type = 125, location = loc(start, pos(start.line, start.column + 1)) }
		end
		local top = self.braceStack[#self.braceStack]
		self.braceStack[#self.braceStack] = nil
		if top ~= "interp" then
			return { type = 125, location = loc(start, pos(start.line, start.column + 1)) }
		end
		return self:readInterpolatedStringSection(start, T.InterpStringMid, T.InterpStringEnd)
	elseif c == 61 then -- '='
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.Equal, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 61, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 60 then -- '<'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.LessEqual, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 60, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 62 then -- '>'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.GreaterEqual, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 62, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 126 then -- '~'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.NotEqual, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 126, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 34 or c == 39 then -- '"' '\''
		return self:readQuotedString()
	elseif c == 96 then -- '`'
		return self:readInterpolatedStringBegin()
	elseif c == 46 then -- '.'
		self:consume()
		if self:peekch() == 46 then
			self:consume()
			if self:peekch() == 46 then
				self:consume()
				return { type = T.Dot3, location = loc(start, pos(start.line, start.column + 3)) }
			elseif self:peekch() == 61 then
				self:consume()
				return { type = T.ConcatAssign, location = loc(start, pos(start.line, start.column + 3)) }
			else
				return { type = T.Dot2, location = loc(start, pos(start.line, start.column + 2)) }
			end
		else
			if isDigit(self:peekch()) then
				return self:readNumber(start, self.offset - 1)
			end
			return { type = 46, location = loc(start, pos(start.line, start.column + 1)) }
		end
	elseif c == 43 then -- '+'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.AddAssign, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 43, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 47 then -- '/'
		self:consume()
		local ch = self:peekch()
		if ch == 61 then
			self:consume()
			return { type = T.DivAssign, location = loc(start, pos(start.line, start.column + 2)) }
		elseif ch == 47 then
			self:consume()
			if self:peekch() == 61 then
				self:consume()
				return { type = T.FloorDivAssign, location = loc(start, pos(start.line, start.column + 3)) }
			end
			return { type = T.FloorDiv, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 47, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 42 then -- '*'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.MulAssign, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 42, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 37 then -- '%'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.ModAssign, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 37, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 94 then -- '^'
		self:consume()
		if self:peekch() == 61 then
			self:consume()
			return { type = T.PowAssign, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 94, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 58 then -- ':'
		self:consume()
		if self:peekch() == 58 then
			self:consume()
			return { type = T.DoubleColon, location = loc(start, pos(start.line, start.column + 2)) }
		end
		return { type = 58, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 40 or c == 41 or c == 93 or c == 59 or c == 44 or c == 35 or c == 63 or c == 38 or c == 124 then
		-- '(' ')' ']' ';' ',' '#' '?' '&' '|'
		self:consume()
		return { type = c, location = loc(start, pos(start.line, start.column + 1)) }
	elseif c == 64 then -- '@'
		if self:peekch(1) == 91 then -- '['
			self:consume()
			self:consume()
			return { type = T.AttributeOpen, location = loc(start, pos(start.line, start.column + 2)) }
		else
			self:consume()
			if isAlpha(self:peekch()) or self:peekch() == 95 then
				local name = self:readName()
				return { type = T.Attribute, location = loc(start, self:position()), data = name }
			else
				return { type = T.Attribute, location = loc(start, self:position()), data = "" }
			end
		end
	else
		if isDigit(c) then
			return self:readNumber(start, self.offset)
		elseif isAlpha(c) or c == 95 then
			local name, ty = self:readName()
			return { type = ty, location = loc(start, self:position()), data = name }
		elseif bit32.band(c, 0x80) ~= 0 then
			return self:readUtf8Error()
		else
			self:consume()
			return { type = c, location = loc(start, pos(start.line, start.column + 1)) }
		end
	end
end

function Lexer.next(self: Lexer, skipComments: boolean?, updatePrevLocation: boolean?): Lexeme
	local sc = if skipComments == nil then self.skipComments else skipComments
	local upl = if updatePrevLocation == nil then true else updatePrevLocation
	repeat
		while isSpace(self:peekch()) do
			self:consumeAny()
		end
		if upl then
			self.prevLocation = self.lexeme.location
		end
		self.lexeme = self:readNext()
		upl = false
	until not (sc and (self.lexeme.type == T.Comment or self.lexeme.type == T.BlockComment))
	return self.lexeme
end

function Lexer.current(self: Lexer): Lexeme
	return self.lexeme
end

function Lexer.lookahead(self: Lexer): Lexeme
	local currentOffset = self.offset
	local currentLine = self.line
	local currentLineOffset = self.lineOffset
	local currentLexeme = self.lexeme
	local currentPrevLocation = self.prevLocation
	local currentBraceStackSize = #self.braceStack
	local currentBraceType = if currentBraceStackSize == 0 then "normal" else self.braceStack[currentBraceStackSize]

	local result = self:next()

	self.offset = currentOffset
	self.line = currentLine
	self.lineOffset = currentLineOffset
	self.lexeme = currentLexeme
	self.prevLocation = currentPrevLocation

	if #self.braceStack < currentBraceStackSize then
		table.insert(self.braceStack, currentBraceType)
	elseif #self.braceStack > currentBraceStackSize then
		self.braceStack[#self.braceStack] = nil
	end

	return result
end

return {
	new = new,
	T = T,
	reservedWords = reservedWords,
	isSpace = isSpace,
	isDigit = isDigit,
	isAlpha = isAlpha,
	isHexDigit = isHexDigit,
}
