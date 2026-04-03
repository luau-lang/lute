--[[
    Given an absolute path, returns a list of paths in the filesystem which match
    the given pattern.
    
    The implementation here follows the Rust implementation of glob.

    These are the rules:

    - `?` matches any single character (not `/`)
    - `*` matches any (possibly empty) sequence of characters (not `/`)
    - `**` matches the current directory and arbitrary subdirectories; it must
      form an entire path component on its own (e.g. `a/**/b` is valid, but
      `a**b` is not)
    - `[...]` matches any character inside the brackets; ranges like `[a-z]`
      are supported, ordered by Unicode code point
    - `[!...]` matches any character NOT inside the brackets
    - Metacharacters can be matched literally by wrapping them in brackets,
      e.g. `[?]` matches a literal `?`, `[*]` matches a literal `*`
]]
local fs = require("@std/fs")
local path = require("@std/path")

local function matches(pattern: string, name: string, pi: number?, ni: number?): boolean
	local pattern_index = pi or 1
	local name_index = ni or 1
	while pattern_index <= #pattern do
		local pc = string.sub(pattern, pattern_index, pattern_index)
		if pc == "*" then
			pattern_index += 1
			for i = name_index, #name + 1 do
				if matches(pattern, name, pattern_index, i) then
					return true
				end
			end
			return false
		elseif pc == "?" then
			if name_index > #name then
				return false
			end
			pattern_index += 1
			name_index += 1
		elseif pc == "[" then
			if name_index > #name then
				return false
			end
			local nc = string.sub(name, name_index, name_index)
			pattern_index += 1
			local negate = string.sub(pattern, pattern_index, pattern_index) == "!"
			if negate then
				pattern_index += 1
			end
			local found = false
			while pattern_index <= #pattern and string.sub(pattern, pattern_index, pattern_index) ~= "]" do
				local lo = string.sub(pattern, pattern_index, pattern_index)
				pattern_index += 1
				if
					string.sub(pattern, pattern_index, pattern_index) == "-"
					and pattern_index + 1 <= #pattern
					and string.sub(pattern, pattern_index + 1, pattern_index + 1) ~= "]"
				then
					pattern_index += 1
					local hi = string.sub(pattern, pattern_index, pattern_index)
					pattern_index += 1
					if nc >= lo and nc <= hi then
						found = true
					end
				else
					if nc == lo then
						found = true
					end
				end
			end
			pattern_index += 1
			if negate then
				found = not found
			end
			if not found then
				return false
			end
			name_index += 1
		else
			if name_index > #name or string.sub(name, name_index, name_index) ~= pc then
				return false
			end
			pattern_index += 1
			name_index += 1
		end
	end
	return name_index > #name
end

local function walk(dir: string, segments: { string }, si: number, results: { string })
	if si > #segments then
		return
	end
	local ok, entries = pcall(fs.listDirectory, dir)
	if not ok then
		return
	end
	local segment = segments[si]
	local isLast = si == #segments
	if segment == "**" then
		if not isLast then
			walk(dir, segments, si + 1, results)
		end
		for _, entry in entries do
			local entryPath = path.format(path.join(dir, entry.name))
			if isLast then
				table.insert(results, entryPath)
			end
			if entry.type == "dir" then
				walk(entryPath, segments, si, results)
			end
		end
	else
		for _, entry in entries do
			if matches(segment, entry.name) then
				local entryPath = path.format(path.join(dir, entry.name))
				if isLast then
					table.insert(results, entryPath)
				elseif entry.type == "dir" then
					walk(entryPath, segments, si + 1, results)
				end
			end
		end
	end
end

-- We define as a table to allow future expansion with parameterised variants
local glob = {}

function glob.glob(input: path.Pathlike): { string }
	local parsed = path.parse(input)
	local parts: { string } = parsed.parts

	local splitAt = #parts + 1
	for i, part in parts do
		if string.find(part, "[%*%?%[]") then
			splitAt = i
			break
		end
	end

	if splitAt > #parts then
		local formatted = path.format(parsed)
		if fs.exists(formatted) then
			return { formatted }
		end
		return {}
	end

	local prefix = path.format({
		parts = { table.unpack(parts, 1, splitAt - 1) },
		absolute = parsed.absolute,
	})
	local segments = { table.unpack(parts, splitAt) }

	local results: { string } = {}
	walk(prefix, segments, 1, results)
	table.sort(results)
	return results
end

return glob
