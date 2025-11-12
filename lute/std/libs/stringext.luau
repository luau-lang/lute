--!strict
-- @std/stringext
-- stdlib for an extension of the built-in string library in Luau
-- Provides additional utility functions for string operations

local stringext = {}

function stringext.startswith(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

function stringext.removeprefix(str: string, prefix: string): string
	if not stringext.startswith(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

function stringext.endswith(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

function stringext.removesuffix(str: string, suffix: string): string
	if not stringext.endswith(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

function stringext.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

return table.freeze(stringext)
