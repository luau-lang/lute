--!strict
-- @std/string
-- stdlib for the built-in string library in Luau
-- Provides additional utility functions for string operations

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

-- re-exports
strings.byte = string.byte
strings.char = string.char
strings.find = string.find
strings.format = string.format
strings.gmatch = string.gmatch
strings.gsub = string.gsub
strings.len = string.len
strings.lower = string.lower
strings.match = string.match
strings.pack = string.pack
strings.packsize = string.packsize
strings.rep = string.rep
strings.reverse = string.reverse
strings.split = string.split
strings.sub = string.sub

return table.freeze(strings)
