--!strict
--!native
-- @std/json
-- JSON serialization and deserialization library

local json = {
	--- A sentinel value representing JSON `null`. Not actually `nil` — use this when you need to serialize a null field.
	null = newproxy() :: nil,
}

--- A JSON object: a table with string keys.
export type Object = { [string]: Value }
--- A JSON array: a table with integer keys.
export type Array = { [number]: Value }
--- Any JSON value: `null`, a number, string, boolean, array, or object.
export type Value = nil | number | string | boolean | Array | Object

-- a unique key to identify an object vs a table
local object_key = newproxy()

-- serialization

local bufferSize = 1024

type SerializerState = {
	buf: buffer,
	cursor: number,
	prettyPrint: boolean,
	depth: number,
}

local function checkState(state: SerializerState, len: number): ()
	local curLen = buffer.len(state.buf)

	if state.cursor + len < curLen then
		return
	end

	local newBuffer = buffer.create(curLen * 2)

	buffer.copy(newBuffer, 0, state.buf)

	state.buf = newBuffer
end

local function writeByte(state: SerializerState, byte: number): ()
	checkState(state, 1)

	buffer.writeu8(state.buf, state.cursor, byte)

	state.cursor += 1
end

local function writeSpaces(state: SerializerState): ()
	if not state.prettyPrint or state.depth == 0 then
		return
	end

	checkState(state, state.depth * 4)

	for _ = 1, state.depth do
		buffer.writeu32(state.buf, state.cursor, 0x_20_20_20_20)
		state.cursor += 4
	end
end

local function writeString(state: SerializerState, str: string): ()
	checkState(state, #str)

	buffer.writestring(state.buf, state.cursor, str)

	state.cursor += #str
end

local serializeAny: (SerializerState, (Array | Object | boolean | number | string)?) -> ()

local STRING_ESCAPES: { [string]: string } = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}
for i = 0, 31 do
	local c = string.char(i)
	if not STRING_ESCAPES[c] then
		STRING_ESCAPES[c] = string.format("\\u%04x", i)
	end
end

local STRING_NEEDS_ESCAPE = '[%z\1-\31"\\]'

local function serializeString(state: SerializerState, str: string): ()
	local escaped: string
	if string.find(str, STRING_NEEDS_ESCAPE) then
		escaped = string.gsub(str, STRING_NEEDS_ESCAPE, STRING_ESCAPES)
	else
		escaped = str
	end

	local sl = #escaped
	checkState(state, sl + 2)
	buffer.writeu8(state.buf, state.cursor, 0x22)
	buffer.writestring(state.buf, state.cursor + 1, escaped)
	buffer.writeu8(state.buf, state.cursor + 1 + sl, 0x22)
	state.cursor += sl + 2
end

local function serializeArray(state: SerializerState, array: Array): ()
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

		writeSpaces(state)

		serializeAny(state, value)
	end

	state.depth -= 1

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
		writeSpaces(state)
	end

	writeByte(state, string.byte("]"))
end

local function serializeTable(state: SerializerState, object: Object): ()
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

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		first = false

		writeSpaces(state)

		serializeString(state, key)
		writeString(state, if state.prettyPrint then ": " else ":")

		serializeAny(state, value)
	end

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth -= 1

	writeSpaces(state)

	writeByte(state, string.byte("}"))
end

serializeAny = function(state: SerializerState, value: Value): ()
	if value == json.null then
		writeString(state, "null")
	elseif typeof(value) == "boolean" then
		writeString(state, if value then "true" else "false")
	elseif typeof(value) == "number" then
		writeString(state, tostring(value))
	elseif typeof(value) == "string" then
		serializeString(state, value)
	elseif typeof(value) == "table" then
		if #value == 0 and next(value :: { [unknown]: unknown }) ~= nil then
			serializeTable(state, value :: Object)
		else
			serializeArray(state, value :: Array)
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
	local b = string.byte(state.src, state.cursor)
	if b == nil then
		return false
	end
	if b ~= 0x20 and b ~= 0x09 and b ~= 0x0A and b ~= 0x0D then
		return true
	end

	state.cursor = string.find(state.src, "[^ \n\r\t]", state.cursor) :: number
	if not state.cursor then
		return false
	end
	return true
end

local function currentByte(state: DeserializerState): number
	return (string.byte(state.src, state.cursor))
end

local function deserializeNumber(state: DeserializerState): number?
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

local UNESCAPE: { [string]: string } = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
}

local function decodeUnicodeEscape(hex: string, cursor: number): string
	local cp = tonumber(hex, 16) :: number
	if cp >= 0xD800 and cp <= 0xDBFF then
		error(`JSON error - Incomplete surrogate pair around {cursor}`)
	end
	if cp >= 0xDC00 and cp <= 0xDFFF then
		error(`JSON error - Lone low surrogate around {cursor}`)
	end
	return utf8.char(cp)
end

local function decodeSurrogatePair(highHex: string, lowHex: string, cursor: number): string
	local high = tonumber(highHex, 16) :: number
	local low = tonumber(lowHex, 16) :: number
	if low < 0xDC00 or low > 0xDFFF then
		error(`JSON error - Invalid unicode surrogate pair around {cursor}`)
	end
	local codepoint = 0x10000 + ((high - 0xD800) * 0x400) + (low - 0xDC00)
	return utf8.char(codepoint)
end

local function deserializeString(state: DeserializerState): string
	if currentByte(state) ~= string.byte('"') then
		return deserializerError(state, "Expected string opening quote")
	end

	local startPos = state.cursor + 1
	local src = state.src

	local p = string.find(src, '[\\"%z\1-\31]', startPos)
	if not p then
		return deserializerError(state, "Unterminated string")
	end
	local b = string.byte(src, p)
	if b == 0x22 then
		state.cursor = p + 1
		return string.sub(src, startPos, p - 1)
	end
	if b ~= 0x5C then
		state.cursor = p
		return deserializerError(state, "Unescaped control character in string")
	end

	local len = #src
	while p <= len do
		local c = string.byte(src, p)
		if c == 0x5C then
			p += 2
		elseif c == 0x22 then
			break
		elseif c < 0x20 then
			state.cursor = p
			return deserializerError(state, "Unescaped control character in string")
		else
			p += 1
		end
	end
	if p > len then
		return deserializerError(state, "Unterminated string")
	end

	local raw = string.sub(src, startPos, p - 1)
	local cursor = state.cursor

	-- Freeze raw `\\` as 0x01 so a `\\u0000` source isn't mis-parsed as
	-- backslash + `\u0000`. The scan above guarantees no 0x01 in input.
	raw = string.gsub(raw, "\\\\", "\1")
	raw = string.gsub(
		raw,
		"\\u([dD][89aAbB]%x%x)\\u([dD][c-fC-F]%x%x)",
		function(h, l)
			return decodeSurrogatePair(h, l, cursor)
		end :: any
	)
	raw = string.gsub(raw, "\\u(%x%x%x%x)", function(code)
		return decodeUnicodeEscape(code, cursor)
	end)
	raw = string.gsub(raw, "\\(.)", function(esc)
		local v = UNESCAPE[esc]
		if not v then
			error(`JSON error - Invalid escape sequence around {cursor}`)
		end
		return v
	end)
	raw = string.gsub(raw, "\1", "\\")

	state.cursor = p + 1
	return raw
end

local deserialize: (DeserializerState) -> (Array | Object | boolean | number | string)?

local function deserializeArray(state: DeserializerState): Array
	if currentByte(state) ~= string.byte("[") then
		return deserializerError(state, "Expected array opening '['")
	end

	state.cursor += 1
	skipWhitespace(state)

	local current: Array = {}
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

local function deserializeObject(state: DeserializerState): Object
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

deserialize = function(state: DeserializerState): Value
	skipWhitespace(state)

	local src = state.src
	local cursor = state.cursor
	local b = string.byte(src, cursor)

	if b == 0x22 then -- '"'
		return deserializeString(state)
	elseif b == 0x7B then -- '{'
		local obj = deserializeObject(state)
		obj[object_key] = true
		return obj
	elseif b == 0x5B then -- '['
		return deserializeArray(state)
	elseif b == 0x74 then -- 't' -> "true"
		local b1, b2, b3 = string.byte(src, cursor + 1, cursor + 3)
		if b1 == 0x72 and b2 == 0x75 and b3 == 0x65 then
			state.cursor = cursor + 4
			return true
		end
	elseif b == 0x66 then -- 'f' -> "false"
		local b1, b2, b3, b4 = string.byte(src, cursor + 1, cursor + 4)
		if b1 == 0x61 and b2 == 0x6C and b3 == 0x73 and b4 == 0x65 then
			state.cursor = cursor + 5
			return false
		end
	elseif b == 0x6E then -- 'n' -> "null"
		local b1, b2, b3 = string.byte(src, cursor + 1, cursor + 3)
		if b1 == 0x75 and b2 == 0x6C and b3 == 0x6C then
			state.cursor = cursor + 4
			return json.null
		end
	elseif b == 0x2D or (b ~= nil and b >= 0x30 and b <= 0x39) then
		return deserializeNumber(state)
	end

	return deserializerError(state, `Unexpected token '{string.sub(src, cursor, cursor)}'`)
end

-- user-facing

--- Serializes `value` to a JSON string. If `prettyPrint` is `true`, the output is indented for readability.
function json.serialize(value: Value, prettyPrint: boolean?): string
	local state: SerializerState = {
		buf = buffer.create(bufferSize),
		cursor = 0,
		prettyPrint = prettyPrint or false,
		depth = 0,
	}

	serializeAny(state, value)

	return buffer.readstring(state.buf, 0, state.cursor)
end

--- Parses a JSON string and returns the corresponding Luau value. Returns `json.null` for a JSON `null` literal; compare with `json.null` rather than `nil` to check for null.
function json.deserialize(src: string): (Array | Object | boolean | number | string)?
	local state = {
		src = src,
		cursor = 1,
	}

	local result = deserialize(state)

	-- After parsing a value, there must be no non-whitespace trailing characters.
	if skipWhitespace(state) then
		deserializerError(state, "Trailing characters after JSON value")
	end

	return result
end

--- Creates a JSON `Object` from `props`. Use this to distinguish an empty object `{}` from an empty array when serializing.
function json.object(props: { [string]: Value }): Object
	local res: Object = { [object_key] = true }

	for key, value in props do
		res[key] = value
	end

	return res
end

--- Returns `value` as an `Object` if it is a JSON object, or `nil` otherwise.
function json.asObject(value: Value): Object?
	if typeof(value) == "table" and value[object_key] then
		return value :: Object
	end

	return nil
end

--- Returns `value` as an `Array` if it is a JSON array, or `nil` otherwise.
function json.asArray(value: Value): Array?
	if typeof(value) == "table" and not value[object_key] then
		return value :: Array
	end

	return nil
end

return table.freeze(json)
