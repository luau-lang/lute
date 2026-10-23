local path = require("@std/path")
local glob = require("@batteries/glob")

type FilePattern = {
	pattern: string,
	excluded: boolean,
	onlyDirectories: boolean,
}

type FilesFilter = {
	hasInclude: boolean,
	patterns: { FilePattern },
}

export type State = {
	files: FilesFilter?,
}

local function relativePath(parts: { string }): string
	return path.format({
		parts = parts,
		absolute = false,
	})
end

-- Patterns use gitignore-style path matching, with ! reversed: normal patterns
-- include and ! patterns exclude. 
local function parsePattern(entry: string): FilePattern
	local negated = string.sub(entry, 1, 1) == "!"
	local pattern = if negated then string.sub(entry, 2) else entry
	local onlyDirectories = string.sub(pattern, -1) == "/"
	if onlyDirectories then
		pattern = string.sub(pattern, 1, -2)
	end

	local anchored = string.sub(pattern, 1, 1) == "/"
	if anchored then
		pattern = string.sub(pattern, 2)
	elseif not string.find(pattern, "/", 1, true) and string.sub(pattern, 1, 3) ~= "**/" then
		pattern = "**/" .. pattern
	end
	if string.sub(pattern, -3) == "/**" then
		pattern ..= "/*"
	end

	return {
		pattern = pattern,
		excluded = negated,
		onlyDirectories = onlyDirectories,
	}
end

local function parseFilesFilter(patterns: { string }?): FilesFilter?
	if patterns == nil then
		return nil
	end

	local filter: FilesFilter = {
		hasInclude = false,
		patterns = {},
	}
	for _, entry in patterns do
		if string.sub(entry, 1, 1) ~= "!" then
			filter.hasInclude = true
		end
		table.insert(filter.patterns, parsePattern(entry))
	end
	return filter
end

local function matchesPattern(pattern: FilePattern, parts: { string }, isDirectory: boolean): boolean
	if (not pattern.onlyDirectories or isDirectory) and glob.match(pattern.pattern, relativePath(parts)) then
		return true
	end

	-- A directory match applies to every file nested under that directory. This
	-- lets a later rule restore an individual descendant of an excluded directory.
	for index = 1, #parts - 1 do
		if glob.match(pattern.pattern, relativePath({ table.unpack(parts, 1, index) })) then
			return true
		end
	end

	return false
end

local function matchPatterns(patterns: { FilePattern }, parts: { string }, isDirectory: boolean): boolean?
	local matched: boolean? = nil
	for _, pattern in patterns do
		if matchesPattern(pattern, parts, isDirectory) then
			matched = not pattern.excluded
		end
	end
	return matched
end

local function new(files: { string }?): State
	return {
		files = parseFilesFilter(files),
	}
end

-- Directories must always be traversed so that a later pattern can restore a
-- descendant of a directory excluded by an earlier pattern. Unmatched files
-- are excluded only when an include pattern exists.
function includes(state: State, parts: { string }, isDirectory: boolean): boolean
	if state.files == nil then
		return true
	end

	local matched = matchPatterns(state.files.patterns, parts, isDirectory)
	if matched ~= nil then
		return matched
	end
	return isDirectory or not state.files.hasInclude
end

-- Hidden paths are never selected implicitly. They must have a final,
-- positive match from an explicit `files` entry.
function explicitlyIncludes(state: State, parts: { string }, isDirectory: boolean): boolean
	return state.files ~= nil and matchPatterns(state.files.patterns, parts, isDirectory) == true
end

return table.freeze({
	explicitlyIncludes = explicitlyIncludes,
	includes = includes,
	new = new,
})
