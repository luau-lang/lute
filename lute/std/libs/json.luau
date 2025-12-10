--!strict
-- @std/json
-- JSON serialization and deserialization library

local json = {
	--- Not actually a nil value, a newproxy stand-in for a null value since Luau has no actual representation of `null`
	null = newproxy() :: nil,
}

export type object = { [string]: value }
export type array = { [number]: value }
export type value = nil | number | string | boolean | array | object

-- a unique key to identify an object vs a table
local object_key = newproxy()

-- serialization

type SerializerState = {
	buf: buffer,
	cursor: number,
	prettyPrint: boolean,
	depth: number,
}

local function checkState(state: SerializerState, len: number)
	local curLen = buffer.len(state.buf)

	if state.cursor + len < curLen then
		return
	end

	local newBuffer = buffer.create(curLen * 2)

	buffer.copy(newBuffer, 0, state.buf)

	state.buf = newBuffer
end

local function writeByte(state: SerializerState, byte: number)
	checkState(state, 1)

	buffer.writeu8(state.buf, state.cursor, byte)

	state.cursor += 1
end

local function writeSpaces(state: SerializerState)
	if state.depth == 0 then
		return
	end

	if state.prettyPrint then
		checkState(state, state.depth * 4)

		for i = 1, state.depth do
			buffer.writeu32(state.buf, state.cursor, 0x_20_20_20_20)
			state.cursor += 4
		end
	else
		buffer.writeu8(state.buf, state.cursor, (string.byte(" ")))

		state.cursor += 1
	end
end

local function writeString(state: SerializerState, str: string)
	checkState(state, #str)

	buffer.writestring(state.buf, state.cursor, str)

	state.cursor += #str
end

local serializeAny: (SerializerState, (array | object | boolean | number | string)?) -> ()

local ESCAPE_MAP = {
	[0x5C] = string.byte("\\"), -- 5C = '\'
	[0x08] = string.byte("b"),
	[0x0C] = string.byte("f"),
	[0x0A] = string.byte("n"),
	[0x0D] = string.byte("r"),
	[0x09] = string.byte("t"),
	[0x22] = string.byte('"'),
}

local function serializeUnicode(codepoint: number)
	if codepoint >= 0x10000 then
		local high = math.floor((codepoint - 0x10000) / 0x400) + 0xD800
		local low = ((codepoint - 0x10000) % 0x400) + 0xDC00
		return string.format("\\u%04x\\u%04x", high, low)
	end

	return string.format("\\u%04x", codepoint)
end

local function serializeString(state: SerializerState, str: string)
	checkState(state, #str)

	writeByte(state, string.byte('"'))

	for pos, codepoint in utf8.codes(str) do
		if ESCAPE_MAP[codepoint] then
			writeByte(state, string.byte("\\"))
			writeByte(state, ESCAPE_MAP[codepoint])
		elseif codepoint < 32 or codepoint > 126 then
			writeString(state, serializeUnicode(codepoint))
		else
			writeString(state, utf8.char(codepoint))
		end
	end

	writeByte(state, string.byte('"'))
end

local function serializeArray(state: SerializerState, array: array)
	state.depth += 1

	writeByte(state, string.byte("["))

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
	end

	for i, value in array do
		if i ~= 1 then
			writeByte(state, string.byte(","))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		if i ~= 1 or state.prettyPrint then
			writeSpaces(state)
		end

		serializeAny(state, value)
	end

	state.depth -= 1

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
		writeSpaces(state)
	end

	writeByte(state, string.byte("]"))
end

local function serializeTable(state: SerializerState, object: object)
	writeByte(state, string.byte("{"))

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth += 1

	local first = true
	for key, value in object do
		if key == object_key then
			continue
		end

		if not first then
			writeByte(state, string.byte(","))
			writeByte(state, string.byte(" "))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		first = false

		writeSpaces(state)

		serializeString(state, key)
		writeString(state, ": ")

		serializeAny(state, value)
	end

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth -= 1

	writeSpaces(state)

	writeByte(state, string.byte("}"))
end

serializeAny = function(state: SerializerState, value: value)
	local valueType = type(value)

	if value == json.null then
		writeString(state, "null")
	elseif valueType == "boolean" then
		writeString(state, if value then "true" else "false")
	elseif valueType == "number" then
		writeString(state, tostring(value))
	elseif valueType == "string" then
		serializeString(state, value :: string)
	elseif valueType == "table" then
		if #(value :: {}) == 0 and next(value :: { [unknown]: unknown }) ~= nil then
			serializeTable(state, value :: object)
		else
			serializeArray(state, value :: array)
		end
	else
		error("Unknown value", 2)
	end
end

-- deserialization

type DeserializerState = {
	src: string,
	cursor: number,
}

local function deserializerError(state: DeserializerState, msg: string): never
	return error(`JSON error - {msg} around {state.cursor}`)
end

local function skipWhitespace(state: DeserializerState): boolean
	state.cursor = string.find(state.src, "[^ \n\r\t]", state.cursor) :: number

	if not state.cursor then
		return false
	end

	return true
end

local function currentByte(state: DeserializerState)
	return string.byte(state.src, state.cursor)
end

local function deserializeNumber(state: DeserializerState)
	-- Integer part
	local nStart, nEnd = string.find(state.src, "^-?[1-9]%d*", state.cursor)
	if not nStart then
		nStart, nEnd = string.find(state.src, "^-?0", state.cursor)
		if not nStart then
			deserializerError(state, "Malformed number (bad integer part)")
		end

		local nextChar = string.byte(state.src, nEnd :: number + 1)
		if nextChar and nextChar >= string.byte("0") and nextChar <= string.byte("9") then
			deserializerError(state, "Malformed number (leading zeros not allowed)")
		end
	end

	-- Decimal part
	local decStart, decEnd = string.find(state.src, "^%.%d+", nEnd :: number + 1)
	if decStart then
		nEnd = decEnd
	end

	-- Exponential part
	local expStart, expEnd = string.find(state.src, "^[eE][+-]?%d+", nEnd :: number + 1)
	if expStart then
		nEnd = expEnd
	end

	local num = tonumber(string.sub(state.src, nStart :: number, nEnd))
	if not num then
		deserializerError(state, "Malformed number value")
	end

	state.cursor = nEnd :: number + 1
	return num
end

local function deserializeString(state: DeserializerState): string
	-- Must start with "
	if currentByte(state) ~= string.byte('"') then
		return deserializerError(state, "Expected string opening quote")
	end

	-- Skip opening quote "
	state.cursor += 1

	local startPos = state.cursor

	local result = {}

	while startPos <= #state.src do
		local c = string.sub(state.src, startPos, startPos)

		-- End of string
		if c == '"' then
			state.cursor = startPos + 1
			return table.concat(result)
		end

		-- Normal character
		if c ~= "\\" then
			local byte = string.byte(c)

			-- No raw control chars allowed
			if byte < 0x20 then
				return deserializerError(state, "Unescaped control character in string")
			end

			table.insert(result, c)
			startPos += 1
		else
			-- Escape sequence
			local source = string.sub(state.src, startPos + 1, startPos + 1)

			if source == "b" then
				table.insert(result, "\b")
				startPos += 2
			elseif source == "f" then
				table.insert(result, "\f")
				startPos += 2
			elseif source == "n" then
				table.insert(result, "\n")
				startPos += 2
			elseif source == "r" then
				table.insert(result, "\r")
				startPos += 2
			elseif source == "t" then
				table.insert(result, "\t")
				startPos += 2
			elseif source == '"' then
				table.insert(result, '"')
				startPos += 2
			elseif source == "\\" then
				table.insert(result, "\\")
				startPos += 2
			elseif source == "/" then
				table.insert(result, "/")
				startPos += 2
			elseif source == "u" then
				-- Unicode escape: \uXXXX
				local hex = string.sub(state.src, startPos + 2, startPos + 5)
				if not hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
					return deserializerError(state, "Invalid \\u escape")
				end

				local codepoint = tonumber(hex, 16)
				if not codepoint then
					return deserializerError(state, "Invalid \\u escape")
				end
				startPos += 6 -- skip \uXXXX

				-- Surrogate pair
				if codepoint >= 0xD800 and codepoint <= 0xDBFF then
					-- Look for \uDCxx following
					local lo = state.src:match("^\\u([dD][cdefCDEF][0-9a-fA-F][0-9a-fA-F])", startPos)
					if lo then
						local lo_val = tonumber(lo, 16)
						-- Combine surrogate halves
						codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (lo_val - 0xDC00)
						startPos += 6
					end
				end

				table.insert(result, utf8.char(codepoint))
			else
				-- Invalid escape: \" already covered
				return deserializerError(state, "Invalid escape sequence '\\" .. source .. "'")
			end
		end
	end

	return deserializerError(state, "Unterminated string")
end

local deserialize: (DeserializerState) -> (array | object | boolean | number | string)?

local function deserializeArray(state: DeserializerState): array
	if currentByte(state) ~= string.byte("[") then
		return deserializerError(state, "Expected array opening '['")
	end

	state.cursor += 1
	skipWhitespace(state)

	local current: array = {}
	local index = 1

	-- empty array
	if currentByte(state) == string.byte("]") then
		state.cursor += 1
		return current
	end

	local expectingValue = true

	while state.cursor <= #state.src do
		if not expectingValue then
			-- Expect a comma or closing bracket
			if currentByte(state) == string.byte(",") then
				expectingValue = true
				state.cursor += 1
				if not skipWhitespace(state) then
					return deserializerError(state, "Unterminated array")
				end
			elseif currentByte(state) == string.byte("]") then
				state.cursor += 1
				return current
			else
				return deserializerError(state, "Expected ',' or ']' after array value")
			end
		else
			-- Expect a value next
			if currentByte(state) == string.byte("]") then
				if index == 1 then
					-- empty array is ok
					state.cursor += 1
					return current
				else
					return deserializerError(state, "Trailing comma in array")
				end
			end

			table.insert(current, deserialize(state))
			index += 1
			expectingValue = false
		end

		if not skipWhitespace(state) then
			return deserializerError(state, "Unterminated array")
		end
	end

	return deserializerError(state, "Unterminated array")
end

local function deserializeObject(state: DeserializerState): object
	state.cursor += 1

	local current = {}

	local expectingValue = false
	while state.cursor < #state.src do
		skipWhitespace(state)

		if currentByte(state) == string.byte("}") then
			break
		end

		skipWhitespace(state)

		if currentByte(state) ~= string.byte('"') then
			return deserializerError(state, "Expected a string key")
		end

		local key = deserializeString(state)

		skipWhitespace(state)

		if currentByte(state) ~= string.byte(":") then
			return deserializerError(state, "Expected ':' for key value pair")
		end

		state.cursor += 1

		local value = deserialize(state)

		current[key] = value

		if not skipWhitespace(state) then
			deserializerError(state, "Unterminated object")
		end

		skipWhitespace(state)

		if currentByte(state) == string.byte(",") then
			expectingValue = true
			state.cursor += 1
		else
			expectingValue = false
		end
	end

	if expectingValue then
		return deserializerError(state, "Trailing comma")
	end

	if not skipWhitespace(state) or currentByte(state) ~= string.byte("}") then
		deserializerError(state, "Unterminated object")
	end

	state.cursor += 1

	return current
end

deserialize = function(state: DeserializerState): value
	skipWhitespace(state)

	local fourChars = string.sub(state.src, state.cursor, state.cursor + 3)

	if string.match(fourChars, "^null") then
		state.cursor += 4
		return json.null
	elseif string.match(fourChars, "^true") then
		state.cursor += 4
		return true
	elseif string.match(string.sub(state.src, state.cursor, state.cursor + 4), "^false") then
		state.cursor += 5
		return false
	elseif string.match(state.src, "^[%-%d]", state.cursor) then
		-- potential number
		return deserializeNumber(state)
	elseif string.match(state.src, '^"', state.cursor) then
		return deserializeString(state)
	elseif string.match(state.src, "^%[", state.cursor) then
		return deserializeArray(state)
	elseif string.match(state.src, "^{", state.cursor) then
		return deserializeObject(state)
	end

	return deserializerError(state, `Unexpected token '{string.sub(state.src, state.cursor, state.cursor)}'`)
end

-- user-facing

function json.serialize(value: value, prettyPrint: boolean?)
	local state: SerializerState = {
		buf = buffer.create(1024),
		cursor = 0,
		prettyPrint = prettyPrint or false,
		depth = 0,
	}

	serializeAny(state, value)

	return buffer.readstring(state.buf, 0, state.cursor)
end

function json.deserialize(src: string)
	local state = {
		src = src,
		cursor = 0,
	}

	local result = deserialize(state)

	-- After parsing a value, there must be no non-whitespace trailing characters.
	if skipWhitespace(state) then
		deserializerError(state, "Trailing characters after JSON value")
	end

	return result
end

function json.object(props: { [string]: value }): object
	local res: object = { [object_key] = true }

	for key, value in props do
		res[key] = value
	end

	return res
end

function json.asobject(value: value): object?
	if typeof(value) == "table" and value[object_key] then
		return value :: object
	end

	return nil
end

function json.asarray(value: value): array?
	if typeof(value) == "table" and not value[object_key] then
		return value :: array
	end

	return nil
end

return table.freeze(json)
