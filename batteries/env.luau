local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local env = {}

export type Environment = { [string]: string }
export type Pathlike = path.Pathlike

export type ParseOptions = {
	expand: boolean?,
	strict: boolean?,
	env: Environment?,
}

export type ApplyOptions = {
	target: Environment?,
	override: boolean?,
}

export type LoadOptions = ParseOptions

export type ConfigOptions = ParseOptions & ApplyOptions & {
	path: Pathlike?,
}

export type SerializeOptions = {
	export: boolean?,
	newline: string?,
}

type QuoteKind = "none" | "single" | "double"

type Entry = {
	line: number,
	value: string,
	quote: QuoteKind,
}

local UTF8_BOM = string.char(239, 187, 191)
local DOLLAR_SENTINEL = "\0"

local function trim(value: string): string
	return (string.match(value, "^%s*(.-)%s*$") or "")
end

local function normalizeInput(input: string): string
	local normalized = string.gsub(input, "\r\n", "\n")
	normalized = string.gsub(normalized, "\r", "\n")

	if string.sub(normalized, 1, #UTF8_BOM) == UTF8_BOM then
		normalized = string.sub(normalized, #UTF8_BOM + 1)
	end

	return normalized
end

local function splitLines(input: string): { string }
	local lines = {}
	for line in string.gmatch(input .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

local function decodeDoubleQuoted(contents: string): string
	local out = {}
	local index = 1

	while index <= #contents do
		local ch = string.sub(contents, index, index)
		if ch ~= "\\" then
			table.insert(out, ch)
			index += 1
			continue
		end

		if index == #contents then
			table.insert(out, "\\")
			break
		end

		local nextCh = string.sub(contents, index + 1, index + 1)
		if nextCh == "n" then
			table.insert(out, "\n")
		elseif nextCh == "r" then
			table.insert(out, "\r")
		elseif nextCh == "t" then
			table.insert(out, "\t")
		elseif nextCh == '"' then
			table.insert(out, '"')
		elseif nextCh == "\\" then
			table.insert(out, "\\")
		elseif nextCh == "$" then
			table.insert(out, DOLLAR_SENTINEL)
		else
			table.insert(out, "\\")
			table.insert(out, nextCh)
		end

		index += 2
	end

	return table.concat(out)
end

local function decodeSingleQuoted(contents: string): string
	local out = {}
	local index = 1

	while index <= #contents do
		local ch = string.sub(contents, index, index)
		if ch == "\\" and index < #contents then
			local nextCh = string.sub(contents, index + 1, index + 1)
			if nextCh == "'" or nextCh == "\\" then
				table.insert(out, nextCh)
				index += 2
				continue
			end
		end

		table.insert(out, ch)
		index += 1
	end

	return table.concat(out)
end

local function parseUnquoted(rawValue: string): string
	local value = {}
	local index = 1

	while index <= #rawValue do
		local ch = string.sub(rawValue, index, index)
		if ch == "#" then
			local prev = if index > 1 then string.sub(rawValue, index - 1, index - 1) else ""
			if index == 1 or prev == " " or prev == "\t" then
				break
			end
		elseif ch == "\\" and index < #rawValue then
			local nextCh = string.sub(rawValue, index + 1, index + 1)
			if nextCh == "#" then
				table.insert(value, "#")
				index += 2
				continue
			elseif nextCh == "$" then
				table.insert(value, DOLLAR_SENTINEL)
				index += 2
				continue
			end
		end

		table.insert(value, ch)
		index += 1
	end

	return trim(table.concat(value))
end

local function isEscaped(value: string, index: number): boolean
	local backslashes = 0
	local scan = index - 1
	while scan >= 1 and string.sub(value, scan, scan) == "\\" do
		backslashes += 1
		scan -= 1
	end
	return backslashes % 2 == 1
end

local function parseQuotedValue(
	lines: { string },
	lineIndex: number,
	rawValue: string,
	quote: QuoteKind
): (string, number)
	local segments = {}
	local currentLineIndex = lineIndex
	local current = string.sub(rawValue, 2)

	while true do
		local index = 1
		while index <= #current do
			local ch = string.sub(current, index, index)
			local escaped = isEscaped(current, index)
			if ch == (if quote == "single" then "'" else '"') and not escaped then
				table.insert(segments, string.sub(current, 1, index - 1))

				local trailing = string.sub(current, index + 1)
				if trailing ~= "" and not string.match(trailing, "^%s*$") and not string.match(trailing, "^%s*#") then
					error(`invalid trailing characters after quoted value on line {lineIndex}`)
				end

				local joined = table.concat(segments, "\n")
				if quote == "single" then
					return decodeSingleQuoted(joined), currentLineIndex
				else
					return decodeDoubleQuoted(joined), currentLineIndex
				end
			end

			index += 1
		end

		table.insert(segments, current)
		currentLineIndex += 1
		if currentLineIndex > #lines then
			error(`unterminated quoted value starting on line {lineIndex}`)
		end
		current = lines[currentLineIndex]
	end
end

local function parseEntries(input: string, options: ParseOptions?): { [string]: Entry }
	local strict = if options and options.strict ~= nil then options.strict else true
	local normalized = normalizeInput(input)
	local lines = splitLines(normalized)
	local entries: { [string]: Entry } = {}

	local lineIndex = 1
	while lineIndex <= #lines do
		local line = lines[lineIndex]
		local stripped = string.match(line, "^%s*(.-)%s*$") or ""

		if stripped == "" or string.sub(stripped, 1, 1) == "#" then
			lineIndex += 1
			continue
		end

		local content = line
		if string.match(content, "^%s*export%s+") then
			content = string.gsub(content, "^(%s*)export%s+", "%1", 1)
		end

		local key, rawValue = string.match(content, "^%s*([%a_][%w_]*)%s*=%s*(.*)$")
		if not key then
			if strict then
				error(`invalid .env assignment on line {lineIndex}`)
			end
			lineIndex += 1
			continue
		end
		assert(rawValue ~= nil)

		local value: string
		local quote: QuoteKind = "none"
		local firstChar = string.sub(rawValue, 1, 1)
		if firstChar == '"' then
			quote = "double"
			value, lineIndex = parseQuotedValue(lines, lineIndex, rawValue, quote)
		elseif firstChar == "'" then
			quote = "single"
			value, lineIndex = parseQuotedValue(lines, lineIndex, rawValue, quote)
		else
			value = parseUnquoted(rawValue)
		end

		entries[key] = {
			line = lineIndex,
			value = value,
			quote = quote,
		}

		lineIndex += 1
	end

	return entries
end

local function parseExpansionExpression(expression: string): (string, string?, string?)
	local name, operator, rest = string.match(expression, "^([%a_][%w_]*)(:?[-+])(.*)$")
	if name then
		assert(operator ~= nil)
		assert(rest ~= nil)
		return name, operator, rest
	end

	local plainName = string.match(expression, "^([%a_][%w_]*)$")
	if plainName then
		return plainName, nil, nil
	end

	error("invalid expansion expression: ${" .. expression .. "}")
end

local function expandEntries(entries: { [string]: Entry }, baseEnv: Environment): Environment
	local resolved: Environment = {}
	local resolving: { [string]: number } = {}
	local stack = {}

	local resolveReference: ((string) -> (string, boolean))? = nil
	local expandValue: ((string) -> string)? = nil

	local function resolveName(name: string): string
		if resolved[name] ~= nil then
			return resolved[name]
		end

		local entry = entries[name]
		if not entry then
			return baseEnv[name] or ""
		end

		if resolving[name] then
			local cycle = {}
			for _, stackName in stack do
				table.insert(cycle, stackName)
			end
			table.insert(cycle, name)
			error(`circular env expansion detected: {table.concat(cycle, " -> ")}`)
		end

		resolving[name] = #stack + 1
		table.insert(stack, name)

		local value = entry.value
		if entry.quote ~= "single" then
			assert(expandValue ~= nil)
			value = expandValue(value)
		end

		resolved[name] = value
		resolving[name] = nil
		table.remove(stack)

		return value
	end

	resolveReference = function(name: string): (string, boolean)
		if entries[name] ~= nil then
			return resolveName(name), true
		end

		local external = baseEnv[name]
		if external ~= nil then
			return external, true
		end

		return "", false
	end

	expandValue = function(value: string): string
		local out = {}
		local index = 1

		while index <= #value do
			local ch = string.sub(value, index, index)

			if ch == DOLLAR_SENTINEL then
				table.insert(out, "$")
				index += 1
				continue
			end

			if ch == "\\" and index < #value and string.sub(value, index + 1, index + 1) == "$" then
				table.insert(out, "$")
				index += 2
				continue
			end

			if ch ~= "$" then
				table.insert(out, ch)
				index += 1
				continue
			end

			local nextCh = if index < #value then string.sub(value, index + 1, index + 1) else ""
			if nextCh == "{" then
				local closeIndex = string.find(value, "}", index + 2, true)
				if not closeIndex then
					error("unterminated expansion expression")
				end

				local expression = string.sub(value, index + 2, closeIndex - 1)
				local name, operator, rest = parseExpansionExpression(expression)
				assert(resolveReference ~= nil)
				local referenced, exists = resolveReference(name)
				local shouldUseRest = false
				local expandedRest = ""

				if rest ~= nil then
					assert(expandValue ~= nil)
					expandedRest = expandValue(rest)
					if operator == "-" then
						shouldUseRest = not exists
					elseif operator == ":-" then
						shouldUseRest = (not exists) or referenced == ""
					elseif operator == "+" then
						shouldUseRest = exists
					elseif operator == ":+" then
						shouldUseRest = exists and referenced ~= ""
					end
				end

				table.insert(out, if shouldUseRest then expandedRest else referenced)
				index = closeIndex + 1
				continue
			end

			local name = string.match(string.sub(value, index + 1), "^([%a_][%w_]*)")
			if name then
				assert(resolveReference ~= nil)
				local referenced = resolveReference(name)
				table.insert(out, referenced)
				index += 1 + #name
				continue
			end

			table.insert(out, "$")
			index += 1
		end

		return table.concat(out)
	end

	for name in entries do
		resolveName(name)
	end

	return resolved
end

local function rawEntriesToEnvironment(entries: { [string]: Entry }): Environment
	local values = {}
	for name, entry in entries do
		values[name] = string.gsub(entry.value, DOLLAR_SENTINEL, "$")
	end
	return values
end

local function encodeDoubleQuoted(value: string): string
	value = string.gsub(value, "\\", "\\\\")
	value = string.gsub(value, "\n", "\\n")
	value = string.gsub(value, "\r", "\\r")
	value = string.gsub(value, "\t", "\\t")
	value = string.gsub(value, '"', '\\"')
	value = string.gsub(value, "%$", "\\$")
	return value
end

local function serializeValue(value: string): string
	if value == "" then
		return ""
	end

	if string.match(value, [[^[^%s#"'=$]+$]]) then
		return value
	end

	return '"' .. encodeDoubleQuoted(value) .. '"'
end

function env.parse(input: string, options: ParseOptions?): Environment
	local entries = parseEntries(input, options)
	local shouldExpand = if options and options.expand ~= nil then options.expand else false
	if not shouldExpand then
		return rawEntriesToEnvironment(entries)
	end

	local baseEnv = if options and options.env then options.env else process.env
	return expandEntries(entries, baseEnv)
end

function env.serialize(values: Environment, options: SerializeOptions?): string
	local keys = {}
	for name in values do
		assert(string.match(name, "^[%a_][%w_]*$"), `invalid environment variable name: {name}`)
		table.insert(keys, name)
	end

	table.sort(keys)

	local lines = {}
	local prefix = if options and options.export then "export " else ""
	for _, name in keys do
		table.insert(lines, prefix .. name .. "=" .. serializeValue(values[name]))
	end

	local newline = if options and options.newline then options.newline else "\n"
	return table.concat(lines, newline)
end

function env.load(filepath: Pathlike, options: LoadOptions?): Environment
	local contents = fs.readFileToString(filepath)
	return env.parse(contents, options)
end

function env.apply(values: Environment, options: ApplyOptions?): Environment
	local target = if options and options.target then options.target else process.env
	local override = if options and options.override ~= nil then options.override else false

	for name, value in values do
		if override or target[name] == nil then
			target[name] = value
		end
	end

	return target
end

function env.config(options: ConfigOptions?): Environment
	local filepath = if options and options.path then options.path else ".env"
	local baseEnv = if options and options.env
		then options.env
		else if options and options.target then options.target else process.env
	local values = env.load(filepath, {
		expand = if options then options.expand else nil,
		strict = if options then options.strict else nil,
		env = baseEnv,
	})

	local target = if options and options.target then options.target else process.env
	env.apply(values, {
		target = target,
		override = if options then options.override else nil,
	})

	return values
end

return table.freeze(env)
