local strings = {}

function strings.startswith(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

function strings.removeprefix(str: string, prefix: string): string
	if not strings.startswith(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

function strings.endswith(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

function strings.removesuffix(str: string, suffix: string): string
	if not strings.endswith(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

function strings.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

return table.freeze({
	startswith = strings.startswith,
	removeprefix = strings.removeprefix,
	endswith = strings.endswith,
	removesuffix = strings.removesuffix,
	trim = strings.trim,

	-- re-exports of the table library
	byte = string.byte,
	char = string.char,
	find = string.find,
	format = string.format,
	gmatch = string.gmatch,
	gsub = string.gsub,
	len = string.len,
	lower = string.lower,
	match = string.match,
	pack = string.pack,
	packsize = string.packsize,
	rep = string.rep,
	reverse = string.reverse,
	split = string.split,
	sub = string.sub,
})
