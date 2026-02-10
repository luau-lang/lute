local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local system = require("@std/system")

export type Glob = { pattern: string, onlyMatchDirectories: boolean, matchAnywhere: boolean }

export type GitignoreData = {
	location: string,
	ignores: { Glob },
	whitelists: { Glob },
	next: GitignoreData?,
}

local separator = if system.win32 then "\\" else "/"

local parseIgnores = {}

--- Converts a glob pattern into a Luau string pattern for efficient matching
--- The output pattern should be matched against a filepath that is relative to the .gitignore location
local function parseGlob(glob: string): Glob
	local onlyMatchDirectories = false

	if glob:sub(-1) == "/" then
		onlyMatchDirectories = true
		glob = glob:sub(1, -2)
	end

	local lua_parts = {}
	local matchAnywhere = false
	local idx = 1
	local len = #glob

	-- If there is a separator at the beginning or middle (or both) of the pattern, then the pattern is relative to
	-- the directory level of the particular .gitignore file itself.
	-- i.e., anchor the pattern to the start
	if glob:find("/") then
		table.insert(lua_parts, "^")
		if glob:sub(1, 2) == "./" then
			idx = 3
		elseif glob:sub(1, 1) == "/" or glob:sub(1, 1) == "." then
			idx = 2
		end
	else
		-- If no leading slash, it can match anywhere, including after a directory.
		-- This means it can start at the beginning of the string, or after a slash.
		-- We can't match for two distinct patterns bc Lua lacks an OR pattern operator
		-- Instead add unique marker we check for in matchesGlob, indicating we match
		-- against the two distinct patterns: anchored at beginning, or after a slash
		matchAnywhere = true
	end

	while idx <= len do
		local char = glob:sub(idx, idx)
		if char == "*" then
			if glob:sub(idx, idx + 1) == "**" then
				if idx == 1 and glob:sub(idx + 2, idx + 2) == "/" then
					-- Leading '**/' at start of the file. If we've already determined matchAnywhere,
					-- we don't need to add an extra character match
					if matchAnywhere then
						idx = idx + 2
						continue
					end
				end
				if glob:sub(idx + 2, idx + 2) == "/" then
					-- ** between slashes (e.g., a/**/b)
					-- Zero or more directory segments - match everything, and don't include the following `/` slash
					table.insert(lua_parts, ".*")
					idx = idx + 3
				else
					-- Trailing ** (e.g., foo/**) or just `**`
					table.insert(lua_parts, ".*") -- Matches anything, including slashes
					idx = idx + 2
				end
			else
				-- Single asterisk `*` (matches anything except directory separator)
				table.insert(lua_parts, `[^{separator}]*`)
				idx = idx + 1
			end
		elseif char == "?" then
			-- Match any single character, except for directory separator
			table.insert(lua_parts, `[^{separator}]`)
			idx = idx + 1
		elseif char == "-" or char == "." then
			table.insert(lua_parts, `%{char}`)
			idx = idx + 1
		elseif char == "/" or char == "\\" then
			table.insert(lua_parts, separator)
			idx = idx + 1
		else
			table.insert(lua_parts, char)
			idx = idx + 1
		end
	end

	-- Add the ending anchor if not already an implicit `.*` from `**`
	if glob:sub(-2) ~= "**" then
		table.insert(lua_parts, "$")
	end

	return {
		pattern = table.concat(lua_parts),
		onlyMatchDirectories = onlyMatchDirectories,
		matchAnywhere = matchAnywhere,
	}
end

function parseIgnores.parseIgnoreContents(location: string, contents: string | { string }): GitignoreData
	local lines = if typeof(contents) == "string" then contents:split("\n") else contents

	local ignoreData: GitignoreData = {
		location = location,
		ignores = {},
		whitelists = {},
	}

	for _, line in lines do
		line = stringext.trim(line)

		if line == "" or stringext.hasprefix(line, "#") then
			continue
		end

		if stringext.hasprefix(line, "!") then
			local globPattern = stringext.removeprefix(line, "!")
			local glob = parseGlob(globPattern)
			table.insert(ignoreData.whitelists, glob)
		else
			local glob = parseGlob(line)
			table.insert(ignoreData.ignores, glob)
		end
	end

	return ignoreData
end

function parseIgnores.parseGitignore(filepath: path.path): GitignoreData
	local contents = fs.readfiletostring(path.format(filepath))
	local parentDirectory = if #filepath.parts > 0 then path.dirname(filepath) else nil
	assert(parentDirectory)
	return parseIgnores.parseIgnoreContents(parentDirectory, contents)
end

function parseIgnores.matchesGlob(glob: Glob, filepath: string, isDirectory: boolean): boolean
	if glob.onlyMatchDirectories and not isDirectory then
		return false
	end
	-- If the pattern is marked with matchAnywhere, we need to test
	-- both: at start of path OR after any directory separator
	if glob.matchAnywhere then
		local matchAtStart = filepath:match("^" .. glob.pattern) ~= nil
		local matchAfterDir = filepath:match(separator .. glob.pattern) ~= nil

		return matchAtStart or matchAfterDir
	else
		return filepath:match(glob.pattern) ~= nil
	end
end

function parseIgnores.isIgnored(ignoreData: GitignoreData, filepath: string, isDirectory: boolean)
	local matched, ignored = false, false

	local relativePath = path.format(path.relative(ignoreData.location, filepath))

	for _, ignore in ignoreData.ignores do
		if parseIgnores.matchesGlob(ignore, relativePath, isDirectory) then
			matched = true
			ignored = true
			break
		end
	end

	if ignored then
		for _, whitelist in ignoreData.whitelists do
			if parseIgnores.matchesGlob(whitelist, filepath, isDirectory) then
				matched = true
				ignored = false
				break
			end
		end
	end

	if not matched and ignoreData.next then
		return parseIgnores.isIgnored(ignoreData.next, filepath, isDirectory)
	end

	return ignored
end

return table.freeze(parseIgnores)
