--[[
    Glob pattern matching and filesystem discovery.

    `glob.match(pattern, input)` tests whether a path matches a glob pattern.
    `glob.discover(pattern)` walks the filesystem returning all matching `Path`s.

    The implementation follows the Rust glob crate. The rules are:

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

local function matchesSegment(pattern: string, name: string, patternStart: number?, nameStart: number?): boolean
	local patternIndex = patternStart or 1
	local nameIndex = nameStart or 1
	while patternIndex <= #pattern do
		local patternChar = string.sub(pattern, patternIndex, patternIndex)
		if patternChar == "*" then
			patternIndex += 1
			for candidateIndex = nameIndex, #name + 1 do
				if matchesSegment(pattern, name, patternIndex, candidateIndex) then
					return true
				end
			end
			return false
		elseif patternChar == "?" then
			if nameIndex > #name then
				return false
			end
			patternIndex += 1
			nameIndex += 1
		elseif patternChar == "[" then
			if nameIndex > #name then
				return false
			end
			local nameChar = string.sub(name, nameIndex, nameIndex)
			patternIndex += 1
			local negate = string.sub(pattern, patternIndex, patternIndex) == "!"
			if negate then
				patternIndex += 1
			end
			local found = false
			while patternIndex <= #pattern and string.sub(pattern, patternIndex, patternIndex) ~= "]" do
				local rangeLow = string.sub(pattern, patternIndex, patternIndex)
				patternIndex += 1
				if
					string.sub(pattern, patternIndex, patternIndex) == "-"
					and patternIndex + 1 <= #pattern
					and string.sub(pattern, patternIndex + 1, patternIndex + 1) ~= "]"
				then
					patternIndex += 1
					local rangeHigh = string.sub(pattern, patternIndex, patternIndex)
					patternIndex += 1
					if nameChar >= rangeLow and nameChar <= rangeHigh then
						found = true
					end
				else
					if nameChar == rangeLow then
						found = true
					end
				end
			end
			patternIndex += 1
			if negate then
				found = not found
			end
			if not found then
				return false
			end
			nameIndex += 1
		else
			if nameIndex > #name or string.sub(name, nameIndex, nameIndex) ~= patternChar then
				return false
			end
			patternIndex += 1
			nameIndex += 1
		end
	end
	return nameIndex > #name
end

type MatchResult = "match" | "no_match" | "partial"

-- Matches input path segments against pattern segments, returning:
--   "match"    — full match (all pattern and input segments consumed)
--   "partial"  — input consumed but pattern segments remain (worth descending)
--   "no_match" — input diverges from pattern (prune)
local function matchStep(
	patternSegments: { string },
	inputSegments: { string },
	patternIndex: number,
	inputIndex: number
): MatchResult
	while patternIndex <= #patternSegments do
		local segment = patternSegments[patternIndex]
		if segment == "**" then
			local best: MatchResult = "no_match"
			for candidateIndex = inputIndex, #inputSegments + 1 do
				local result = matchStep(patternSegments, inputSegments, patternIndex + 1, candidateIndex)
				if result == "match" then
					return "match"
				elseif result == "partial" then
					best = "partial"
				end
			end
			return best
		else
			if inputIndex > #inputSegments then
				return "partial"
			end
			if not matchesSegment(segment, inputSegments[inputIndex]) then
				return "no_match"
			end
			patternIndex += 1
			inputIndex += 1
		end
	end
	if inputIndex > #inputSegments then
		return "match"
	end
	return "no_match"
end

local function walk(directory: path.Pathlike, segments: { string }, segmentIndex: number, results: { path.Path })
	if segmentIndex > #segments then
		return
	end
	local success, entries = pcall(fs.listDirectory, directory)
	if not success then
		return
	end
	local segment = segments[segmentIndex]
	local isLast = segmentIndex == #segments
	if segment == "**" then
		if not isLast then
			walk(directory, segments, segmentIndex + 1, results)
		end
		for _, entry in entries do
			local entryPath = path.join(directory, entry.name)
			if isLast then
				table.insert(results, entryPath)
			end
			if entry.type == "dir" then
				walk(entryPath, segments, segmentIndex, results)
			end
		end
	else
		for _, entry in entries do
			if matchesSegment(segment, entry.name) then
				local entryPath = path.join(directory, entry.name)
				if isLast then
					table.insert(results, entryPath)
				elseif entry.type == "dir" then
					walk(entryPath, segments, segmentIndex + 1, results)
				end
			end
		end
	end
end

local glob = {}

-- Returns true if the given path matches the glob pattern, without touching the filesystem.
function glob.match(pattern: path.Pathlike, input: path.Pathlike): boolean
	local patternParts = path.parse(pattern).parts
	local inputParts = path.parse(input).parts
	return matchStep(patternParts, inputParts, 1, 1) == "match"
end

-- Walks the filesystem and returns all paths matching the glob pattern.
function glob.discover(input: path.Pathlike): { path.Path }
	local parsed = path.parse(input)
	local parts: { string } = parsed.parts

	local firstGlobIndex = #parts + 1
	for index, part in parts do
		if string.find(part, "[%*%?%[]") then
			firstGlobIndex = index
			break
		end
	end

	if firstGlobIndex > #parts then
		if fs.exists(parsed) then
			return { parsed }
		end
		return {}
	end

	local prefixPath = table.clone(parsed)
	prefixPath.parts = { table.unpack(parts, 1, firstGlobIndex - 1) }
	local segments = { table.unpack(parts, firstGlobIndex) }

	local results: { path.Path } = {}
	walk(prefixPath, segments, 1, results)
	table.sort(results, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return results
end

return glob
