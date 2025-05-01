local isPrimitiveType = { string = true, number = true, boolean = true }

type ExistingOptions = {
	rawStrings: boolean?,
}

local function isPrimitiveArray(array: { [unknown]: unknown })
	local max, n = 0, 0

	for key, value in array do
		if typeof(key) ~= "number" then
			return false
		end
		if key <= 0 then
			return false
		end
		if not isPrimitiveType[typeof(value)] then
			return false
		end

		max = if key > max then key else max
		n = n + 1
	end

	return n == max
end

local function formatValue(value: unknown, options: ExistingOptions?)
	if typeof(value) == "table" then
		return "table" -- simple representation for table values
	elseif typeof(value) ~= "string" then
		return tostring(value)
	end

	if options ~= nil and options.rawStrings == true then
		return `"{value}"`
	else
		return string.format("%q", value)
	end
end

local function formatKey(key: unknown, seq: boolean)
	if seq then
		return ""
	end

	if typeof(key) == "table" then
		return "[table] = " -- add handling for table keys
	elseif typeof(key) ~= "string" then
		return `[{tostring(key)}] =`
	end

	-- key is a simple identifier
	if key:match("^[%a_][%w_]-$") == key then
		return `{key} = `
	end

	return `[{string.format("%q", key)}] = `
end

local typeSortOrder: { [string]: number } = {
	["boolean"] = 1,
	["number"] = 2,
	["string"] = 3,
	["function"] = 4,
	["vector"] = 5,
	["buffer"] = 6,
	["thread"] = 7,
	["table"] = 8,
	["userdata"] = 9,
	["nil"] = 10,
}

local function traverseTable(
	dataTable: { [unknown]: unknown },
	seen: { [unknown]: boolean },
	indent: number,
	options: ExistingOptions?
)
	local output = ""
	local indentStr = string.rep("  ", indent)

	local keys = {}

	-- Collect all keys, not just primitives
	for key, _ in dataTable do
		keys[#keys + 1] = key
	end

	table.sort(keys, function(a: string, b: string): boolean
		local typeofTableA, typeofTableB = typeof(dataTable[a]), typeof(dataTable[b])

		if typeofTableA ~= typeofTableB then
			return typeSortOrder[typeofTableA] < typeSortOrder[typeofTableB]
		end

		if typeof(a) == "number" and typeof(b) == "number" then
			return a < b
		end

		return tostring(a) < tostring(b)
	end)

	local inSequence = false
	local previousKey = 0

	for idx, key in keys do
		if typeof(key) == "number" and key > 0 and key - 1 == previousKey then
			previousKey = key
			inSequence = true
		else
			inSequence = false
		end

		local value = dataTable[key]
		if typeof(value) ~= "table" then
			output = `{output}{indentStr}{formatKey(key, inSequence)}{formatValue(value, options)},\n`
			continue
		end

		-- prevents self-referential tables from looping infinitely
		if seen[value] then
			output = `{output}{indentStr}{formatKey(key, inSequence)}[Circular Reference],\n`
			continue
		end

		seen[value] = true

		local hasItems = false
		for k, val in value do
			hasItems = true
			break
		end

		if not hasItems then
			output = string.format("%s%s%s{},\n", output, indentStr, formatKey(key, inSequence))
			continue
		end

		-- FIXME(luau): `{[unknown]: unknown} should be treated identically to `table`
		if isPrimitiveArray(value :: { [unknown]: unknown }) then -- collapse primitive arrays
			local valueAsArray = value :: { unknown }

			output = string.format("%s%s%s{", output, indentStr, formatKey(key, inSequence))

			for index = 1, #valueAsArray do
				output ..= formatValue(valueAsArray[index])
				if index < #valueAsArray then
					output ..= ", "
				end
			end

			output ..= "},\n"
			continue
		end

		output = string.format(
			"%s%s%s{\n%s%s},\n",
			output,
			indentStr,
			formatKey(key, inSequence),
			traverseTable(value :: any, seen, indent + 1, options),
			indentStr
		)

		seen[value] = nil
	end

	return output
end

return function(data: unknown, options: ExistingOptions?)
	options = if options then options else {} :: ExistingOptions

	-- if it's not a primitive, we'll pretty print it as a value
	if typeof(data) ~= "table" then
		return formatValue(data, options)
	end

	-- FIXME(luau): `{[unknown]: unknown} should be treated identically to `table`
	return "{\n" .. traverseTable(data :: { [unknown]: unknown }, { [data :: unknown] = true }, 1, options) .. "}"
end
