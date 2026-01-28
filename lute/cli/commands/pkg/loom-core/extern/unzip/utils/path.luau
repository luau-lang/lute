--- Canonicalize a path by removing redundant components
local function canonicalize(path: string): string
	-- We convert any `\\` separators to `/` separators to ensure consistency
	local components = string.split(path:gsub("\\", "/"), "/")
	local result = {}
	for _, component in components do
		if component == "." then
			-- Skip current directory
			continue
		end

		if component == ".." then
			-- Traverse one upwards
			table.remove(result, #result)
			continue
		end

		-- Otherwise, add the component to the result
		table.insert(result, component)
	end

	return table.concat(result, "/")
end

--- Check if a path is absolute
local function isAbsolute(path: string): boolean
	return (
		string.match(path, "^/")
		or string.match(path, "^[a-zA-Z]:[\\/]")
		or string.match(path, "^//")
		or string.match(path, "^\\\\")
	) ~= nil
end

--- Check if a path is relative
local function isRelative(path: string): boolean
	return not isAbsolute(path)
end

local function replaceBackslashes(input: string, replacement: "/"): string
	-- Check if the string starts with double backslashes
	if input:sub(1, 2) == "\\\\" then
		-- Replace all single backslashes except the first two
		return "\\\\" .. input:sub(3):gsub("\\", replacement)
	else
		-- Replace all single backslashes
		return input:gsub("\\", replacement)
	end
end

--- Check if a path is safe to use, i.e., it does not:
--- - Contain null bytes
--- - Resolve to a directory outside of the current directory
--- - Have absolute components
local function isSafe(path: string): boolean
	if string.find(path, "\0") or isAbsolute(path) then
		-- Null bytes or absolute path, path is unsafe
		return false
	end

	local components = string.split(replaceBackslashes(path, "/"), "/")
	local depth = 0
	for _, component in components do
		if string.match(component, "^[a-zA-Z]:$") or string.find(component, "^\\\\") or component == "" then
			-- Was a prefix component, or the root directory, path is unsafe
			return false
		end

		if component == ".." then
			-- Traverse one upwards
			depth -= 1
			if depth < 0 then
				-- Traversed too far, path is unsafe
				return false
			end

			continue
		end

		if component == "." then
			-- Skip current directory
			continue
		end

		-- Otherwise, increment depth
		depth += 1
	end

	return depth >= 0
end

--- Sanitize a path by ignoring special components
--- - Absolute paths become relative
--- - Special components (like upwards traversing) are removed
--- - Truncates path to the first null byte
local function sanitize(path: string): string
	local truncatedPath = if string.find(path, "\0") then string.split(path, "\0")[1] else path
	local components = string.split(replaceBackslashes(truncatedPath, "/"), "/")
	local result = {}
	for _, component in components do
		if
			not (
				component == ".."
				or component == "."
				or component == string.match(component, "^[a-zA-Z]:$")
				or string.find(component, "^\\\\")
				or component == ""
			)
		then
			-- If the path is not a special component, add it to the result
			table.insert(result, component)
		end
	end

	return table.concat(result, "/")
end

return {
	canonicalize = canonicalize,
	isAbsolute = isAbsolute,
	isRelative = isRelative,
	isSafe = isSafe,
	sanitize = sanitize,
}
