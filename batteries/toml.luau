local toml = {}

-- serialization

local function serializeValue(value: string | number): string
	if typeof(value) == "string" then
		value = string.gsub(value, "\\", "\\\\")
		value = string.gsub(value, "\n", "\\n")
		value = string.gsub(value, "\t", "\\t")
		return '"' .. value .. '"'
	end

	if value == math.huge then
		return "inf"
	end

	if value == -math.huge then
		return "-inf"
	end

	if value ~= value then
		return "nan"
	end

	return tostring(value)
end

local function quoteKey(key: string): string
	if not string.match(key, "^[%w_-]+$") then
		return `"{key}"`
	end

	return key
end

local function hasNestedTables(tbl: { [unknown]: unknown }): boolean
	for _, v in tbl do
		if typeof(v) == "table" and next(v) ~= nil then
			return true
		end
	end

	return false
end

local function tableToToml(tbl: { [any]: any }, parent: string?): string
	local result = ""
	local subTables = {}
	local hasDirectValues = false

	for k, v in tbl do
		if typeof(v) == "table" and next(v) ~= nil then
			if #v > 0 then
				for _, entry in v do
					result ..= "\n[[" .. (parent and parent .. "." or "") .. quoteKey(k) .. "]]\n"
					result ..= tableToToml(entry, nil)
				end
			else
				subTables[k] = v
			end
		else
			hasDirectValues = true
			result ..= quoteKey(k) .. " = " .. serializeValue(v) .. "\n"
		end
	end

	for k, v in subTables do
		local key = parent and (parent .. "." .. quoteKey(k)) or quoteKey(k)

		if hasNestedTables(v) == true then
			result ..= tableToToml(v, key)
			continue
		end

		if hasDirectValues or parent then
			result ..= "\n[" .. key .. "]\n"
		end

		result ..= tableToToml(v, key)
	end

	return result
end

local function serialize(tbl: { [any]: any }): string
	return tableToToml(tbl, nil)
end

-- deserialization

export type TomlValue = string | number | boolean | { TomlValue } | { [string]: TomlValue }

local function deserialize(input: string): { [string]: TomlValue }
	-- convert CRLF to LF
	if input:find("\r\n", 1, true) then
		input = input:gsub("\r\n", "\n")
	end

	-- Reject bare CR (only CRLF → LF is allowed)
	if input:find("\r", 1, true) then
		error("TOML parse error: bare carriage return (\\r) not allowed")
	end

	-- Validate UTF-8 encoding
	do
		local i = 1
		local n = #input
		while i <= n do
			local b = string.byte(input, i)
			local seqLen: number

			if b < 0x80 then
				seqLen = 1
			elseif b < 0xC2 then
				error("TOML parse error: invalid UTF-8 byte at position " .. i)
			elseif b < 0xE0 then
				seqLen = 2
			elseif b < 0xF0 then
				seqLen = 3
			elseif b <= 0xF4 then
				seqLen = 4
			else
				error("TOML parse error: invalid UTF-8 byte at position " .. i)
			end

			if i + seqLen - 1 > n then
				error("TOML parse error: truncated UTF-8 sequence at position " .. i)
			end

			-- Validate continuation bytes and overlong/surrogate checks
			if seqLen == 2 then
				local b2 = string.byte(input, i + 1)
				if b2 < 0x80 or b2 > 0xBF then
					error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 1))
				end
			elseif seqLen == 3 then
				local b2 = string.byte(input, i + 1)
				local b3 = string.byte(input, i + 2)
				if b == 0xE0 then
					if b2 < 0xA0 or b2 > 0xBF then
						error("TOML parse error: overlong UTF-8 sequence at position " .. i)
					end
				elseif b == 0xED then
					if b2 < 0x80 or b2 > 0x9F then
						error("TOML parse error: UTF-8 surrogate codepoint at position " .. i)
					end
				else
					if b2 < 0x80 or b2 > 0xBF then
						error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 1))
					end
				end
				if b3 < 0x80 or b3 > 0xBF then
					error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 2))
				end
			elseif seqLen == 4 then
				local b2 = string.byte(input, i + 1)
				local b3 = string.byte(input, i + 2)
				local b4 = string.byte(input, i + 3)

				if b == 0xF0 then
					if b2 < 0x90 or b2 > 0xBF then
						error("TOML parse error: overlong UTF-8 sequence at position " .. i)
					end
				elseif b == 0xF4 then
					if b2 < 0x80 or b2 > 0x8F then
						error("TOML parse error: UTF-8 codepoint > U+10FFFF at position " .. i)
					end
				else
					if b2 < 0x80 or b2 > 0xBF then
						error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 1))
					end
				end

				if b3 < 0x80 or b3 > 0xBF then
					error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 2))
				end

				if b4 < 0x80 or b4 > 0xBF then
					error("TOML parse error: invalid UTF-8 continuation at position " .. (i + 3))
				end
			end
			i += seqLen
		end
	end

	local src = input
	local pos = 1
	local len = #src
	local srcBuf = buffer.fromstring(src)

	-- Table metadata: maps table reference -> { kind, keys }
	type TableKind =
		| "root" -- the document root
		| "defined" -- created by an explicit [header]
		| "implicit-header" -- implicitly created while navigating a [a.b.c] path
		| "implicit-dotted" -- implicitly created by a dotted key assignment (a.b = v)
		| "inline" -- an inline table; immutable after creation
		| "array-element" -- an element of an [[array-of-tables]]
		| "array-value" -- a static array literal (cannot be navigated into)
	type TableMeta = { kind: TableKind, keys: { [string]: boolean } }
	local tableMeta: { [any]: TableMeta } = {}

	-- tracks which Luau arrays are array-of-tables (vs regular array values)
	local arrayTableSets: { [any]: boolean } = {}

	local function getMeta(tbl: any): TableMeta
		if not tableMeta[tbl] then
			tableMeta[tbl] = { kind = "implicit-header", keys = {} }
		end
		return tableMeta[tbl]
	end

	local function tomlParseError(msg: string): never
		error(`TOML parse error at position {pos}: {msg}`)
	end

	-- character helpers (all operate on the shared pos/src/len upvalues)

	local function byteAt(offset: number?): number? -- byte at pos+offset
		local p = pos + (offset or 0)
		return if p <= len then buffer.readu8(srcBuf, p - 1) else nil
	end

	local function isDigit(c: number?): boolean
		return c ~= nil and c >= 48 and c <= 57
	end

	local function isHexDigit(c: number?): boolean
		return c ~= nil and ((c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102))
	end

	local function isOctDigit(c: number?): boolean
		return c ~= nil and c >= 48 and c <= 55
	end

	local function isBinDigit(c: number?): boolean
		return c ~= nil and (c == 48 or c == 49)
	end

	-- bare key chars: A-Z a-z 0-9 _ -
	local function isBareKey(c: number?): boolean
		if c == nil then
			return false
		end

		return (c >= 97 and c <= 122) or (c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c == 95 or c == 45
	end

	-- control characters that are forbidden unescaped (everything < 0x20 except tab,
	-- plus DEL 0x7F; LF 0x0A is handled separately per context)
	local function isControlCharacter(c: number?): boolean
		if c == nil then
			return false
		end

		return c <= 8 or c == 11 or c == 12 or (c >= 14 and c <= 31) or c == 127
	end

	-- whitespace skipping

	local function skipWhitespace()
		while pos <= len do
			local c = buffer.readu8(srcBuf, pos - 1)

			if c ~= 32 and c ~= 9 then
				break
			end

			pos += 1
		end
	end

	-- skip a # comment up to (but not including) the newline
	local function skipComment()
		if byteAt() ~= 35 then
			return
		end -- '#'

		pos += 1

		while pos <= len do
			local c = buffer.readu8(srcBuf, pos - 1)

			if c == 10 then
				break
			end

			if isControlCharacter(c) then
				tomlParseError("control character in comment")
			end

			pos += 1
		end
	end

	-- skip horizontal whitespace, newlines, and comments
	local function skipWhitespaceNewlinesAndComments()
		while pos <= len do
			local c = buffer.readu8(srcBuf, pos - 1)

			if c == 32 or c == 9 or c == 10 then
				pos += 1
			elseif c == 35 then
				skipComment()
			else
				break
			end
		end
	end

	-- after a value: consume trailing whitespace + optional comment, then require newline or EOF
	local function expectLineEnd()
		skipWhitespace()
		skipComment()

		if pos > len then
			return
		end

		local c = byteAt()
		if c == 10 then
			pos += 1
		else
			tomlParseError(`expected newline or EOF, got '${string.char(c :: number)}'`)
		end
	end

	-- string escape helpers

	local function parseUnicodeEscape(long: boolean): string
		local n = if long then 8 else 4
		local hexStr = string.sub(src, pos, pos + n - 1)

		if #hexStr < n then
			tomlParseError("incomplete unicode escape")
		end

		for i = 1, n do
			if not isHexDigit(string.byte(hexStr, i)) then
				tomlParseError("invalid hex digit in unicode escape")
			end
		end

		pos += n

		local cp = tonumber(hexStr, 16) :: number

		if cp >= 0xD800 and cp <= 0xDFFF then
			tomlParseError("surrogate codepoint in unicode escape")
		end

		if cp > 0x10FFFF then
			tomlParseError("unicode codepoint out of range")
		end

		return utf8.char(cp)
	end

	-- \xXX escape (TOML 1.1): unicode codepoint U+0000..U+00FF
	local function parseHexEscape(): string
		local hexStr = string.sub(src, pos, pos + 1)

		if #hexStr < 2 or not isHexDigit(string.byte(hexStr, 1)) or not isHexDigit(string.byte(hexStr, 2)) then
			tomlParseError("invalid \\x escape")
		end

		pos += 2

		return utf8.char(tonumber(hexStr, 16) :: number)
	end

	local function parseEscape(): string
		if pos > len then
			tomlParseError("incomplete escape sequence")
		end

		local c = byteAt() :: number
		pos += 1

		if c == 98 then
			return "\b"
		end

		if c == 116 then
			return "\t"
		end

		if c == 110 then
			return "\n"
		end

		if c == 102 then
			return "\f"
		end

		if c == 114 then
			return "\r"
		end

		if c == 34 then
			return '"'
		end

		if c == 92 then
			return "\\"
		end

		if c == 101 then
			return "\x1B"
		end -- \e  (TOML 1.1)

		if c == 117 then
			return parseUnicodeEscape(false)
		end -- \uXXXX

		if c == 85 then
			return parseUnicodeEscape(true)
		end -- \UXXXXXXXX

		if c == 120 then
			return parseHexEscape()
		end -- \xXX  (TOML 1.1)

		tomlParseError(`invalid escape sequence \\${string.char(c)}`)
		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	-- string parsers (pos is always past the opening delimiter on entry)

	local function parseBasicString(): string
		local parts = {}

		while pos <= len do
			-- Fast path: scan forward over plain characters in one go
			local runStart = pos

			while pos <= len do
				local c2 = buffer.readu8(srcBuf, pos - 1)

				-- break on: " (34), \ (92), DEL (127), ctrl chars except tab (9)
				if c2 == 34 or c2 == 92 or c2 == 127 or (c2 < 32 and c2 ~= 9) then
					break
				end

				pos += 1
			end

			if pos > runStart then
				table.insert(parts, string.sub(src, runStart, pos - 1))
			end

			if pos > len then
				break
			end

			local c = buffer.readu8(srcBuf, pos - 1)

			if c == 34 then -- closing "
				pos += 1
				return table.concat(parts)
			end

			if c == 92 then -- backslash
				pos += 1
				table.insert(parts, parseEscape())
				continue
			end

			if c == 10 then
				tomlParseError("unescaped newline in basic string")
			end

			tomlParseError("unescaped control character in basic string")
		end

		tomlParseError("unterminated basic string")

		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	local function parseMultilineBasicString(): string
		-- trim a single leading newline
		if byteAt() == 10 then
			pos += 1
		end

		local parts = {}

		while pos <= len do
			-- Fast path: scan over plain chars (LF and tab are literal content too)
			local runStart = pos

			while pos <= len do
				local c2 = buffer.readu8(srcBuf, pos - 1)

				-- break on: " (34), \ (92), DEL (127), ctrl except tab (9) and LF (10)
				if c2 == 34 or c2 == 92 or c2 == 127 or (c2 < 32 and c2 ~= 9 and c2 ~= 10) then
					break
				end

				pos += 1
			end

			if pos > runStart then
				table.insert(parts, string.sub(src, runStart, pos - 1))
			end

			if pos > len then
				break
			end

			local c = buffer.readu8(srcBuf, pos - 1)

			if c == 34 then
				if string.sub(src, pos, pos + 2) == '"""' then
					pos += 3
					local extra = 0

					while pos <= len and buffer.readu8(srcBuf, pos - 1) == 34 and extra < 2 do
						table.insert(parts, '"')
						pos += 1
						extra += 1
					end

					return table.concat(parts)
				end

				-- lone " is valid content in a multiline basic string
				table.insert(parts, '"')
				pos += 1

				continue
			end

			if c == 92 then -- backslash
				pos += 1

				-- peek past trailing horizontal whitespace to detect line-ending backslash
				local peek = pos

				while peek <= len do
					local pc = buffer.readu8(srcBuf, peek - 1)

					if pc ~= 32 and pc ~= 9 then
						break
					end

					peek += 1
				end

				if peek <= len and buffer.readu8(srcBuf, peek - 1) == 10 then
					-- line-ending backslash: skip newline and all following whitespace and newlines
					pos = peek + 1
					while pos <= len do
						local c3 = buffer.readu8(srcBuf, pos - 1)
						if c3 ~= 32 and c3 ~= 9 and c3 ~= 10 then
							break
						end
						pos += 1
					end
				elseif peek > len then
					tomlParseError("incomplete escape at end of file")
				else
					table.insert(parts, parseEscape())
				end

				continue
			end

			-- ctrl char or DEL
			tomlParseError("unescaped control character in multiline basic string")
		end

		tomlParseError("unterminated multiline basic string")

		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	local function parseLiteralString(): string
		local start = pos

		while pos <= len do
			local c = buffer.readu8(srcBuf, pos - 1)
			if c == 39 then -- closing '
				local result = string.sub(src, start, pos - 1)
				pos += 1
				return result
			end

			if c == 9 or (c >= 32 and c ~= 127) or c >= 128 then
				pos += 1 -- plain char (tab, printable ASCII, or multibyte UTF-8)
				continue
			end

			if c == 10 then
				tomlParseError("unescaped newline in literal string")
			end

			tomlParseError("unescaped control character in literal string")
		end

		tomlParseError("unterminated literal string")

		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	local function parseMultilineLiteralString(): string
		if byteAt() == 10 then
			pos += 1
		end -- trim leading newline

		local parts = {}

		while pos <= len do
			-- Fast path: scan over plain chars (LF and tab are literal content)
			local runStart = pos
			while pos <= len do
				local c2 = buffer.readu8(srcBuf, pos - 1)
				-- break on: ' (39), DEL (127), ctrl except tab (9) and LF (10)
				if c2 == 39 or c2 == 127 or (c2 < 32 and c2 ~= 9 and c2 ~= 10) then
					break
				end
				pos += 1
			end

			if pos > runStart then
				table.insert(parts, string.sub(src, runStart, pos - 1))
			end

			if pos > len then
				break
			end

			local c = buffer.readu8(srcBuf, pos - 1)
			if c == 39 then
				if string.sub(src, pos, pos + 2) == "'''" then
					pos += 3
					local extra = 0
					while pos <= len and buffer.readu8(srcBuf, pos - 1) == 39 and extra < 2 do
						table.insert(parts, "'")
						pos += 1
						extra += 1
					end
					return table.concat(parts)
				end
				-- lone ' is valid content in a multiline literal string
				table.insert(parts, "'")
				pos += 1
				continue
			end

			-- ctrl char or DEL
			tomlParseError("unescaped control character in multiline literal string")
		end

		tomlParseError("unterminated multiline literal string")

		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	-- number / datetime helpers

	-- parse a run of digits (with internal underscores allowed), return digits-only string
	local function parseDigits(digitCheck: (number?) -> boolean): string
		if not digitCheck(byteAt()) then
			tomlParseError("expected digit")
		end

		local result = ""
		local runStart = pos

		while pos <= len do
			local c = buffer.readu8(srcBuf, pos - 1)

			if digitCheck(c) then
				pos += 1
			elseif c == 95 then -- underscore
				result ..= string.sub(src, runStart, pos - 1)
				pos += 1

				if pos > len then
					tomlParseError("trailing underscore in number")
				end

				local nc = buffer.readu8(srcBuf, pos - 1)
				if nc == 95 then
					tomlParseError("consecutive underscores in number")
				end

				if not digitCheck(nc) then
					tomlParseError("trailing underscore in number")
				end

				runStart = pos
			else
				break
			end
		end

		result ..= string.sub(src, runStart, pos - 1)
		return result
	end

	local function looksLikeDate(): boolean
		-- YYYY- : 4 decimal digits followed by '-'
		if pos + 4 > len then
			return false
		end

		for i = 0, 3 do
			if not isDigit(buffer.readu8(srcBuf, pos + i - 1)) then
				return false
			end
		end

		return buffer.readu8(srcBuf, pos + 3) == 45
	end

	local function looksLikeTime(): boolean
		-- HH: : exactly 2 decimal digits followed by ':'
		return isDigit(byteAt(0)) and isDigit(byteAt(1)) and byteAt(2) == 58
	end

	-- Returns days in month for given year and month (1-12)
	local function daysInMonth(year: number, month: number): number
		if month == 2 then
			local isLeap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
			return if isLeap then 29 else 28
		end

		if month == 4 or month == 6 or month == 9 or month == 11 then
			return 30
		end

		return 31
	end

	local function parseDatetime(): string
		local hasDate = looksLikeDate()
		local result = ""

		if hasDate then
			-- Parse YYYY-MM-DD
			local yearStr = string.sub(src, pos, pos + 3)
			pos += 4

			if byteAt() ~= 45 then
				tomlParseError("expected '-' in date")
			end

			pos += 1

			if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
				tomlParseError("expected 2-digit month")
			end

			local monthStr = string.sub(src, pos, pos + 1)
			pos += 2
			local month = tonumber(monthStr) :: number

			if month < 1 or month > 12 then
				tomlParseError(`invalid month: {month}`)
			end

			if byteAt() ~= 45 then
				tomlParseError("expected '-' in date")
			end

			pos += 1

			if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
				tomlParseError("expected 2-digit day")
			end

			local dayStr = string.sub(src, pos, pos + 1)
			pos += 2

			local day = tonumber(dayStr) :: number
			local year = tonumber(yearStr) :: number
			if day < 1 or day > daysInMonth(year, month) then
				tomlParseError(`invalid day {day} for month {month}`)
			end

			result = `{yearStr}-{monthStr}-{dayStr}`

			-- Optional datetime separator: T, t, or space followed by digit
			local sep = byteAt()
			if sep == 84 or sep == 116 then
				pos += 1
			elseif sep == 32 and isDigit(byteAt(1)) then
				pos += 1
			else
				return result -- date-local
			end

			result ..= "T"
		end

		-- Parse HH:MM[:SS[.frac]]
		if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
			tomlParseError("expected 2-digit hour")
		end

		local hourStr = string.sub(src, pos, pos + 1)
		pos += 2
		local hour = tonumber(hourStr) :: number
		if hour > 23 then
			tomlParseError(`invalid hour: {hour}`)
		end

		if byteAt() ~= 58 then
			tomlParseError("expected ':' in time")
		end

		pos += 1
		if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
			tomlParseError("expected 2-digit minute")
		end

		local minStr = string.sub(src, pos, pos + 1)
		pos += 2
		local minute = tonumber(minStr) :: number
		if minute > 59 then
			tomlParseError(`invalid minute: {minute}`)
		end

		result ..= `{hourStr}:{minStr}`

		-- Optional seconds (TOML 1.1)
		local secStr = "00"
		if byteAt() == 58 then
			pos += 1

			if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
				tomlParseError("expected 2-digit second")
			end

			secStr = string.sub(src, pos, pos + 1)
			pos += 2
			local sec = tonumber(secStr) :: number
			if sec > 59 then
				tomlParseError(`invalid second: {sec}`)
			end
		end
		result ..= `:{secStr}`

		-- Optional fractional seconds
		if byteAt() == 46 then
			pos += 1

			if not isDigit(byteAt()) then
				tomlParseError("expected digit after '.' in time")
			end

			local fracStart = pos
			while isDigit(byteAt()) do
				pos += 1
			end

			local fracPart = string.sub(src, fracStart, pos - 1)
			result ..= `.{fracPart}`
		end

		-- Optional offset: Z, +HH:MM, -HH:MM
		local oc = byteAt()
		if oc == 90 or oc == 122 then
			if not hasDate then
				tomlParseError("offset not allowed in time-local")
			end

			pos += 1
			result ..= "Z"
		elseif oc == 43 or oc == 45 then
			if not hasDate then
				tomlParseError("offset not allowed in time-local")
			end

			local sign = string.char(oc :: number)

			pos += 1

			if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
				tomlParseError("expected 2-digit offset hour")
			end

			local ohStr = string.sub(src, pos, pos + 1)
			pos += 2
			local oh = tonumber(ohStr) :: number
			if oh > 23 then
				tomlParseError(`invalid offset hour: {oh}`)
			end

			if byteAt() ~= 58 then
				tomlParseError("expected ':' in offset")
			end

			pos += 1

			if not (isDigit(byteAt(0)) and isDigit(byteAt(1))) then
				tomlParseError("expected 2-digit offset minute")
			end

			local omStr = string.sub(src, pos, pos + 1)
			pos += 2
			local om = tonumber(omStr) :: number
			if om > 59 then
				tomlParseError(`invalid offset minute: {om}`)
			end

			result ..= `{sign}{ohStr}:{omStr}`
		end

		return result
	end

	local parseValue: () -> TomlValue

	local function parseNumOrDatetime(sign: string?): string | number
		local signStr = sign or ""
		local c = byteAt()

		-- bare inf / nan
		if string.sub(src, pos, pos + 2) == "inf" then
			pos += 3
			return if signStr == "-" then -math.huge else math.huge
		end

		if string.sub(src, pos, pos + 2) == "nan" then
			pos += 3
			return 0 / 0
		end

		if not isDigit(c) then
			tomlParseError(`expected digit, got '${string.char(c :: number)}'`)
		end

		-- prefixed integer bases (no sign allowed)
		if sign == nil and c == 48 then
			local nc = byteAt(1)
			if nc == 120 then
				pos += 2
				return tonumber(parseDigits(isHexDigit), 16) :: number
			end -- 0x

			if nc == 111 then
				pos += 2
				return tonumber(parseDigits(isOctDigit), 8) :: number
			end -- 0o

			if nc == 98 then
				pos += 2
				return tonumber(parseDigits(isBinDigit), 2) :: number
			end -- 0b
		end

		-- datetime / time detection (no sign)
		if sign == nil then
			if looksLikeDate() then
				return parseDatetime()
			end

			if looksLikeTime() then
				return parseDatetime()
			end
		end

		-- decimal integer or float
		local isZero = c == 48
		local intDigits: string
		if isZero then
			pos += 1

			if isDigit(byteAt()) then
				tomlParseError("leading zero in integer")
			end

			intDigits = "0"
		else
			intDigits = parseDigits(isDigit)
		end

		local nc = byteAt()
		local isFloat = false
		local result = signStr .. intDigits

		if nc == 46 then -- '.'
			isFloat = true
			pos += 1
			if not isDigit(byteAt()) then
				tomlParseError("expected digit after decimal point")
			end
			result ..= "." .. parseDigits(isDigit)
			nc = byteAt()
		end

		if nc == 101 or nc == 69 then -- e / E
			isFloat = true
			pos += 1
			local expSign = ""
			local ec = byteAt()
			if ec == 43 or ec == 45 then
				expSign = string.char(ec :: number)
				pos += 1
			end
			if not isDigit(byteAt()) then
				tomlParseError("expected digit in exponent")
			end
			result ..= "e" .. expSign .. parseDigits(isDigit)
		end

		return if isFloat then tonumber(result) :: number else tonumber(signStr .. intDigits) :: number
	end

	-- array and inline-table parsers (forward declared for mutual recursion)
	local parseArray: () -> { TomlValue }
	local parseInlineTable: () -> { [string]: TomlValue }
	local parseKey: () -> { string }
	local setNestedKey: (tbl: { [string]: TomlValue }, parts: { string }, value: TomlValue, fromDottedKey: boolean) -> ()

	parseValue = function(): TomlValue
		skipWhitespace()
		if pos > len then
			tomlParseError("expected value")
		end
		local c = byteAt() :: number

		if c == 34 then -- "
			pos += 1
			if string.sub(src, pos, pos + 1) == '""' then
				pos += 2
				return parseMultilineBasicString()
			end
			return parseBasicString()
		end

		if c == 39 then -- '
			pos += 1
			if string.sub(src, pos, pos + 1) == "''" then
				pos += 2
				return parseMultilineLiteralString()
			end
			return parseLiteralString()
		end

		if c == 91 then -- [
			pos += 1
			return parseArray()
		end

		if c == 123 then -- {
			pos += 1
			return parseInlineTable()
		end

		if c == 116 then -- t
			if string.sub(src, pos, pos + 3) == "true" then
				pos += 4
				if isBareKey(byteAt()) then
					tomlParseError("invalid value")
				end
				return true
			end
			tomlParseError("invalid value starting with 't'")
		end

		if c == 102 then -- f
			if string.sub(src, pos, pos + 4) == "false" then
				pos += 5
				if isBareKey(byteAt()) then
					tomlParseError("invalid value")
				end
				return false
			end
			tomlParseError("invalid value starting with 'f'")
		end

		if c == 105 then -- i
			if string.sub(src, pos, pos + 2) == "inf" then
				pos += 3
				return math.huge
			end
			tomlParseError("invalid value starting with 'i'")
		end

		if c == 110 then -- n
			if string.sub(src, pos, pos + 2) == "nan" then
				pos += 3
				return 0 / 0
			end
			tomlParseError("invalid value starting with 'n'")
		end

		if c == 43 then -- +
			pos += 1
			return parseNumOrDatetime("+")
		end

		if c == 45 then -- -
			pos += 1
			return parseNumOrDatetime("-")
		end

		if isDigit(c) then
			return parseNumOrDatetime(nil)
		end

		tomlParseError(`unexpected character '${string.char(c)}' in value`)
		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	parseArray = function(): { TomlValue }
		local result: { TomlValue } = {}
		tableMeta[result] = { kind = "array-value", keys = {} } -- mark as static array

		skipWhitespaceNewlinesAndComments()
		if byteAt() == 93 then
			pos += 1
			return result
		end -- empty []

		while true do
			skipWhitespaceNewlinesAndComments()
			if pos > len then
				tomlParseError("unterminated array")
			end

			if byteAt() == 93 then
				pos += 1
				break
			end -- trailing comma case

			table.insert(result, parseValue())

			skipWhitespaceNewlinesAndComments()

			if pos > len then
				tomlParseError("unterminated array")
			end

			local c = byteAt()
			if c == 44 then -- ','
				pos += 1
				continue
			end

			if c == 93 then -- ']'
				pos += 1
				break
			end

			tomlParseError(`expected ',' or ']' in array, got '${string.char(c :: number)}'`)
		end

		return result
	end

	parseKey = function(): { string }
		skipWhitespace()
		local parts: { string } = {}

		while true do
			local c = byteAt()
			local part: string

			if c == 34 then -- "
				pos += 1
				part = parseBasicString()
			elseif c == 39 then -- '
				pos += 1
				part = parseLiteralString()
			elseif isBareKey(c) then
				local start = pos

				while pos <= len do
					local c2 = buffer.readu8(srcBuf, pos - 1)
					if not isBareKey(c2) then
						break
					end
					pos += 1
				end

				part = string.sub(src, start, pos - 1)
			else
				if #parts == 0 then
					tomlParseError(`expected key, got '${string.char(c :: number or 0)}'`)
				else
					tomlParseError("expected key segment after '.'")
				end
			end

			table.insert(parts, part)

			skipWhitespace()
			if byteAt() == 46 then -- '.'
				pos += 1
				skipWhitespace()
			else
				break
			end
		end

		return parts
	end

	-- navigate through dotted intermediate keys, creating tables as needed;
	-- returns (leaf_table, leaf_key_string)
	local function navigateDotted(
		tbl: { [string]: TomlValue },
		parts: { string },
		newKind: TableKind
	): ({ [string]: TomlValue }, string)
		local current: { [string]: TomlValue } = tbl

		for i = 1, #parts - 1 do
			local k = parts[i]
			local child = current[k]

			if child == nil then
				local newTbl: { [string]: TomlValue } = {}
				tableMeta[newTbl] = { kind = newKind, keys = {} }
				current[k] = newTbl
				getMeta(current).keys[k] = true
				current = newTbl
			elseif typeof(child) == "table" then
				if arrayTableSets[child] then
					tomlParseError(`cannot extend array-of-tables '${k}' via dotted key`)
				end

				local m = getMeta(child)

				if m.kind == "array-value" then
					tomlParseError(`cannot navigate through static array value '${k}'`)
				end

				if m.kind == "inline" then
					tomlParseError(`cannot extend inline table via key '${k}'`)
				end

				if m.kind == "defined" or m.kind == "array-element" then
					tomlParseError(`cannot extend explicitly-defined table '${k}' via dotted key`)
				end

				current = child :: { [string]: TomlValue }
			else
				tomlParseError(`key '${k}' is not a table`)
			end
		end
		return current, parts[#parts]
	end

	setNestedKey = function(tbl: { [string]: TomlValue }, parts: { string }, value: TomlValue, fromDottedKey: boolean)
		local newKind = if fromDottedKey then "implicit-dotted" else "implicit-header"
		local leafTbl, leafKey = navigateDotted(tbl, parts, newKind)

		local m = getMeta(leafTbl)

		if m.keys[leafKey] then
			tomlParseError(`duplicate key '${leafKey}'`)
		end

		m.keys[leafKey] = true
		leafTbl[leafKey] = value

		-- tag any freshly assigned table value
		if typeof(value) == "table" and not tableMeta[value] then
			tableMeta[value] = { kind = newKind, keys = {} }
		end
	end

	parseInlineTable = function(): { [string]: TomlValue }
		local result: { [string]: TomlValue } = {}
		tableMeta[result] = { kind = "inline", keys = {} }
		skipWhitespaceNewlinesAndComments() -- TOML 1.1: newlines allowed inside inline tables

		if byteAt() == 125 then
			pos += 1
			return result
		end -- empty {}

		while true do
			skipWhitespaceNewlinesAndComments()
			if pos > len then
				tomlParseError("unterminated inline table")
			end

			if byteAt() == 125 then
				pos += 1
				break
			end -- '}' (trailing comma support)

			local keys = parseKey()
			skipWhitespace()

			if byteAt() ~= 61 then
				tomlParseError("expected '=' in inline table")
			end -- '='

			pos += 1

			local value = parseValue()
			setNestedKey(result, keys, value, false)
			skipWhitespaceNewlinesAndComments()

			if pos > len then
				tomlParseError("unterminated inline table")
			end

			local c = byteAt()
			if c == 44 then -- ','
				pos += 1
				continue
			end

			if c == 125 then -- '}'
				pos += 1
				break
			end

			tomlParseError(`expected ',' or '}}' in inline table, got '${string.char(c :: number)}'`)
		end

		return result
	end

	-- navigate to the table referenced by a [key] or [[key]] header
	local function navigateToHeader(
		root: { [string]: TomlValue },
		parts: { string },
		isArrayTable: boolean
	): { [string]: TomlValue }
		local current: { [string]: TomlValue } = root
		for i = 1, #parts - 1 do
			local k = parts[i]
			local child = current[k]

			if child == nil then
				local newTbl: { [string]: TomlValue } = {}
				tableMeta[newTbl] = { kind = "implicit-header", keys = {} }
				current[k] = newTbl
				getMeta(current).keys[k] = true
				current = newTbl
			elseif typeof(child) == "table" then
				if arrayTableSets[child] then
					current = (child :: { TomlValue })[#(child :: { TomlValue })] :: { [string]: TomlValue }
				else
					local m = getMeta(child)

					if m.kind == "array-value" then
						tomlParseError(`key '${k}' is a static array, cannot navigate through it`)
					end

					if m.kind == "inline" then
						tomlParseError("cannot extend inline table")
					end

					current = child :: { [string]: TomlValue }
				end
			else
				tomlParseError(`key '${k}' is not a table`)
			end
		end

		local leafKey = parts[#parts]
		local existing = current[leafKey]

		if isArrayTable then
			if existing == nil then
				local arr: { { [string]: TomlValue } } = {}

				arrayTableSets[arr] = true
				current[leafKey] = arr :: { TomlValue }
				getMeta(current).keys[leafKey] = true

				local entry: { [string]: TomlValue } = {}
				tableMeta[entry] = { kind = "array-element", keys = {} }
				table.insert(arr, entry)

				return entry
			end

			if typeof(existing) == "table" and arrayTableSets[existing] then
				local entry: { [string]: TomlValue } = {}
				tableMeta[entry] = { kind = "array-element", keys = {} }
				table.insert(existing :: { { [string]: TomlValue } }, entry)

				return entry
			end

			tomlParseError(`cannot define [[${leafKey}]]: key already exists as a different type`)
		end

		if existing == nil then
			local newTbl: { [string]: TomlValue } = {}
			tableMeta[newTbl] = { kind = "defined", keys = {} }
			current[leafKey] = newTbl
			getMeta(current).keys[leafKey] = true
			return newTbl
		end

		if typeof(existing) == "table" then
			-- Check arrayTableSets BEFORE getMeta to avoid creating spurious meta
			if arrayTableSets[existing] then
				tomlParseError(`cannot define [${leafKey}]: already an array-of-tables`)
			end

			local m = getMeta(existing)

			if m.kind == "array-value" then
				tomlParseError(`cannot define [${leafKey}]: key is a static array value`)
			end

			if m.kind == "implicit-header" then
				m.kind = "defined"
				return existing :: { [string]: TomlValue }
			end

			if m.kind == "defined" then
				tomlParseError(`duplicate table header [${leafKey}]`)
			end

			if m.kind == "inline" then
				tomlParseError("cannot extend inline table with a table header")
			end

			if m.kind == "implicit-dotted" then
				tomlParseError(`table [${leafKey}] was already defined via a dotted key`)
			end

			if m.kind == "array-element" then
				tomlParseError(`cannot define [${leafKey}]: already an array-of-tables element`)
			end

			tomlParseError(`cannot redefine [${leafKey}]`)
		end

		tomlParseError(`key '${leafKey}' is not a table`)

		-- FIXME(Luau): `tomlParseError` paths are not currently treated as not returning
		error("unreachable")
	end

	-- main parse loop

	local root: { [string]: TomlValue } = {}
	tableMeta[root] = { kind = "root", keys = {} }
	local currentTable: { [string]: TomlValue } = root

	while pos <= len do
		skipWhitespaceNewlinesAndComments()
		if pos > len then
			break
		end

		local c = byteAt() :: number

		if c == 91 then -- '['
			if byteAt(1) == 91 then -- '[['
				pos += 2
				skipWhitespace()
				local parts = parseKey()
				skipWhitespace()
				if string.sub(src, pos, pos + 1) ~= "]]" then
					tomlParseError("expected ']]'")
				end
				pos += 2
				expectLineEnd()
				currentTable = navigateToHeader(root, parts, true)
			else
				pos += 1
				skipWhitespace()
				local parts = parseKey()
				skipWhitespace()
				if byteAt() ~= 93 then
					tomlParseError("expected ']'")
				end -- ']'
				pos += 1
				expectLineEnd()
				currentTable = navigateToHeader(root, parts, false)
			end
		else
			local parts = parseKey()
			skipWhitespace()
			if byteAt() ~= 61 then
				tomlParseError("expected '='")
			end -- '='
			pos += 1
			local value = parseValue()
			setNestedKey(currentTable, parts, value, true)
			expectLineEnd()
		end
	end

	return root
end

-- user-facing
toml.serialize = serialize
toml.deserialize = deserialize

return table.freeze(toml)
