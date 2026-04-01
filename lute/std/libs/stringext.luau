--!strict
-- @std/stringext
-- stdlib for an extension of the built-in string library in Luau
-- Provides additional utility functions for string operations

local stringext = {}

function stringext.hasPrefix(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

function stringext.removePrefix(str: string, prefix: string): string
	if not stringext.hasPrefix(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

function stringext.hasSuffix(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

function stringext.removeSuffix(str: string, suffix: string): string
	if not stringext.hasSuffix(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

function stringext.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

-- Counts the number of occurrences of pattern in str between startPos and endPos (inclusive)
function stringext.count(str: string, pattern: string, startPos: number?, endPos: number?): number
	if startPos and endPos then
		str = str:sub(startPos, endPos)
	elseif startPos then
		str = str:sub(startPos)
	elseif endPos then
		str = str:sub(1, endPos)
	end

	local count = 0
	for _ in str:gmatch(pattern) do
		count += 1
	end

	return count
end

return table.freeze(stringext)
