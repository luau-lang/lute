local strings = {}

function strings.startsWith(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

function strings.removePrefix(str: string, prefix: string): string
	if not strings.startsWith(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

function strings.endsWith(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

function strings.removeSuffix(str: string, suffix: string): string
	if not strings.endsWith(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

function strings.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

return strings
