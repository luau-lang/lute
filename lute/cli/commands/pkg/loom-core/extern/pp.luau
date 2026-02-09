type ExistingOptions = {
	rawStrings: boolean?,
}

local isPrimitiveType = { string = true, number = true, boolean = true }

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

local function isPrimitiveArray(array: { [unknown]: unknown }): boolean
	local max, len = 0, #array

	for key, value in array do
		if type(key) ~= "number" then
			return false
		elseif key <= 0 then
			return false
		-- userdatas arent primitives
		elseif not isPrimitiveType[type(value)] then
			return false
		end

		max = math.max(key, max)
	end

	return len == max
end

local function getFormattedAdress(t: {}): string
	return `table<({t})>`
end

local function formatValue(value: unknown, options: ExistingOptions?): string
	if type(value) == "table" then
		return getFormattedAdress(value) -- simple representation for table values
	elseif type(value) ~= "string" then
		return tostring(value)
	end

	if options and options.rawStrings then
		return `"{value}"`
	end
	return string.format("%q", value)
end

local function formatKey(key: unknown, seq: boolean): string
	if seq then
		return ""
	end

	if type(key) == "table" then
		return `[{getFormattedAdress(key)}] = ` -- TODO: handling for table keys
	end
	if type(key) ~= "string" then
		return `[{tostring(key)}] =`
	end

	-- key is a simple identifier
	if string.match(key, "^[%a_][%w_]-$") == key then
		return `{key} = `
	end

	return `[{string.format("%q", key)}] = `
end

local function isEmpty(t: { [unknown]: unknown }): boolean
	for _ in t do
		return false
	end
	return true
end

-- FIXME(luau): mark `dataTable` indexer as read-only
local function traverseTable(
	dataTable: { [unknown]: unknown },
	seen: { [unknown]: boolean },
	indent: number,
	options: ExistingOptions?
): string
	local output = ""
	local indentStr = string.rep("  ", indent)

	local keys = {}

	-- Collect all keys, not just primitives
	for key in dataTable do
		table.insert(keys, key)
	end

	table.sort(keys, function(a: string, b: string): boolean
		local typeofTableA, typeofTableB = typeof(dataTable[a]), typeof(dataTable[b])

		if typeofTableA ~= typeofTableB then
			return typeSortOrder[typeofTableA] < typeSortOrder[typeofTableB]
		end

		if type(a) == "number" and type(b) == "number" then
			return a < b
		end

		return tostring(a) < tostring(b)
	end)

	local inSequence = false
	local previousKey = 0

	for idx, key in keys do
		if type(key) == "number" and key > 0 and key - 1 == previousKey then
			previousKey = key
			inSequence = true
		else
			inSequence = false
		end

		local value = dataTable[key]

		if type(value) ~= "table" then
			output = `{output}{indentStr}{formatKey(key, inSequence)}{formatValue(value, options)},\n`
			continue
		end

		-- prevents self-referential tables from looping infinitely
		if seen[value] then
			output = `{output}{indentStr}{formatKey(key, inSequence)}[Circular Reference <({value})>],\n`
			continue
		else
			seen[value] = true
		end

		if isEmpty(value :: { [unknown]: unknown }) then
			output = string.format("%s%s%s{},\n", output, indentStr, formatKey(key, inSequence))
			continue
		end

		if isPrimitiveArray(value :: { [unknown]: unknown }) then -- collapse primitive arrays
			local outputConcatTbl = table.create(#value) :: { string }

			for valueIndex, valueInArray in value :: { unknown } do
				outputConcatTbl[valueIndex] = formatValue(valueInArray)
			end

			output = string.format(
				"%s%s%s{%*},\n",
				output,
				indentStr,
				formatKey(key, inSequence),
				table.concat(outputConcatTbl, ", ")
			)
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

return function(data: unknown, options: ExistingOptions?): string
	options = options or {} :: ExistingOptions

	-- if it's not a primitive, we'll pretty print it as a value
	if type(data) ~= "table" then
		return formatValue(data, options)
	end

	return `\{\n{traverseTable(data :: { [unknown]: unknown }, { [data] = true }, 1, options)}\}`
end
