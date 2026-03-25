local toml = {}

-- serialization
type SerializerState = {
	buf: buffer,
	cursor: number,
}

local function serializeValue(value: string | number): string
	if typeof(value) == "string" then
		value = string.gsub(value, "\\", "\\\\")
		value = string.gsub(value, "\n", "\\n")
		value = string.gsub(value, "\t", "\\t")
		return '"' .. value .. '"'
	elseif value == math.huge then
		return "inf"
	elseif value == -math.huge then
		return "-inf"
	elseif value ~= value then
		return "nan"
	else
		return tostring(value)
	end
end

local function quoteKey(key: string): string
	if not string.match(key, "^[%w_-]+$") then
		return '"' .. key .. '"'
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
type DeserializerState = {
	buf: string,
	cursor: number,
}

local function splitTablePath(path: string): { string }
	local parts = {}
	local index = 1
	local pathLen = string.len(path)

	while index <= pathLen do
		local symbol = string.sub(path, index, index)
		if symbol == "." then
			index += 1
		elseif symbol == '"' or symbol == "'" then
			local closePos = string.find(path, symbol, index + 1, true) or pathLen + 1
			table.insert(parts, string.sub(path, index + 1, closePos - 1))
			index = closePos + 1
		else
			local nextSpecial = string.find(path, "[.\"']", index)
			local segEnd = if nextSpecial then nextSpecial - 1 else pathLen
			table.insert(parts, string.sub(path, index, segEnd))
			index = segEnd + 1
		end
	end

	return parts
end

local function ensurePath(root: { [string]: unknown }, parts: { string }, depth: number?): { [string]: unknown }
	local current = root
	for i = 1, depth or #parts do
		if not current[parts[i]] then
			current[parts[i]] = {}
		end
		current = current[parts[i]] :: { [string]: unknown }
	end
	return current
end

local function skipWhitespace(state: DeserializerState): ()
	local pos = state.cursor
	while pos <= string.len(state.buf) and string.match(string.sub(state.buf, pos, pos), "%s") do
		pos += 1
	end
	state.cursor = pos
end

local function readLine(state: DeserializerState): string
	local nextLine = string.find(state.buf, "\n", state.cursor) or string.len(state.buf) + 1
	local line = string.sub(state.buf, state.cursor, nextLine - 1)
	state.cursor = nextLine + 1
	return line
end

local function deserialize(input: string): { [string]: unknown }
	-- Normalize line endings: Replace Windows (\r\n) and old Mac (\r) with Unix (\n)
	input = string.gsub(input, "\r\n", "\n")
	input = string.gsub(input, "\r", "\n")

	local state: DeserializerState = {
		buf = input,
		cursor = 1,
	}
	local result: { [string]: unknown } = {}
	local currentTable = result
	local arrayTables = {}

	while state.cursor <= string.len(state.buf) do
		skipWhitespace(state)
		local line = readLine(state)

		if line == "" or string.sub(line, 1, 1) == "#" then
			continue
		end

		if string.match(line, "^%[%[(.-)%]%]$") then
			local tableName = string.match(line, "^%[%[(.-)%]%]$") or ""

			if not arrayTables[tableName] then
				arrayTables[tableName] = {}
				local parts = splitTablePath(tableName)
				local leaf = parts[#parts]
				local _parent = ensurePath(result, parts, #parts - 1)
				_parent[leaf] = arrayTables[tableName]
			end

			local newEntry = {}
			table.insert(arrayTables[tableName], newEntry)
			currentTable = newEntry
		elseif string.match(line, "^%[(.-)%]$") then
			local tablePath = string.match(line, "^%[(.-)%]$")
			currentTable = ensurePath(result, splitTablePath(tablePath :: string))
		elseif string.match(line, "^(.-)%s*=%s*(.-)$") then
			local key, value = string.match(line, "^(.-)%s*=%s*(.-)$")
			assert(key and value)
			key = string.match(key, "^%s*(.-)%s*$")
			value = string.match(value, "^%s*(.-)%s*$")
			assert(key and value)
			if string.match(key, '^"(.*)"$') or string.match(key, "^'(.*)'$") then
				key = string.sub(key, 2, -2)
			end
			if string.match(value, '^"(.*)"$') or string.match(value, "^'(.*)'$") then
				value = string.sub(value, 2, -2)
				value = string.gsub(value, "\\\\", "\\")
				value = string.gsub(value, "\\n", "\n")
				value = string.gsub(value, "\\t", "\t")
			elseif tonumber(value) then
				value = tonumber(value)
			elseif value == "true" then
				value = true
			elseif value == "false" then
				value = false
			elseif value == "inf" or value == "+inf" then
				value = math.huge
			elseif value == "-inf" then
				value = -math.huge
			elseif value == "nan" then
				value = math.nan
			end

			currentTable[key] = value
		end
	end

	return result
end

-- user-facing
toml.serialize = serialize
toml.deserialize = deserialize

return table.freeze(toml)
