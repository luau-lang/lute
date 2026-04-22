--!strict
-- @std/stringext
-- stdlib for an extension of the built-in string library in Luau
-- Provides additional utility functions for string operations

local stringext = {}

--- Returns `true` if `str` begins with `prefix`.
function stringext.hasPrefix(str: string, prefix: string): boolean
	if #prefix > #str then
		return false
	end

	return str:sub(1, #prefix) == prefix
end

--- Returns `str` with `prefix` removed from the front. If `str` does not start with `prefix`, returns `str` unchanged.
function stringext.removePrefix(str: string, prefix: string): string
	if not stringext.hasPrefix(str, prefix) then
		return str
	end

	return str:sub(#prefix + 1)
end

--- Returns `true` if `str` ends with `suffix`.
function stringext.hasSuffix(str: string, suffix: string): boolean
	return str:sub(-#suffix) == suffix
end

--- Returns `str` with `suffix` removed from the end. If `str` does not end with `suffix`, returns `str` unchanged.
function stringext.removeSuffix(str: string, suffix: string): string
	if not stringext.hasSuffix(str, suffix) then
		return str
	end

	return str:sub(0, -#suffix - 1)
end

--- Returns `str` with leading and trailing whitespace removed.
function stringext.trim(str: string): string
	-- Pattern is guaranteed to return a result
	return str:match("^%s*(.-)%s*$") :: string
end

--- Counts the number of occurrences of `pattern` in `str`, optionally restricted to the range `[startPos, endPos]`.
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
