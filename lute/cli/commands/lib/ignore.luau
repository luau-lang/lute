local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local system = require("@std/system")

local separator = if system.win32 then "\\" else "/"

--- Performs ignore resolution on a set of
local IgnoreResolver = {}
IgnoreResolver.__index = IgnoreResolver

type Glob = { pattern: string, onlyMatchDirectories: boolean, matchAnywhere: boolean }

type GitignoreData = {
	location: string,
	ignores: { Glob },
	whitelists: { Glob },
	next: GitignoreData?,
}

type IgnoreResolverData = {
	_ignoreCache: { [string]: GitignoreData },
}

export type IgnoreResolver = setmetatable<IgnoreResolverData, typeof(IgnoreResolver)>

function IgnoreResolver.new(): IgnoreResolver
	local self = {}

	self._ignoreCache = {}

	return setmetatable(self, IgnoreResolver)
end

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
		elseif char == "-" then
			table.insert(lua_parts, "%-")
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

local function parseGitignoreContents(location: string, contents: string): GitignoreData
	local lines = contents:split("\n")

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

local function parseGitignore(filepath: path.path): GitignoreData
	local contents = fs.readfiletostring(path.format(filepath))
	local parentDirectory = if #filepath.parts > 0 then path.dirname(filepath) else nil
	assert(parentDirectory)
	return parseGitignoreContents(parentDirectory, contents)
end

local function matchesGlob(glob: Glob, filepath: string, isDirectory: boolean): boolean
	if glob.onlyMatchDirectories and not isDirectory then
		return false
	end
	-- If the pattern is marked with matchAnywhere, we need to test
	-- both: at start of path OR after any directory separator
	if glob.matchAnywhere then
		local matchAtStart = filepath:match("^" .. glob.pattern) ~= nil
		local matchAfterDir = filepath:match("/" .. glob.pattern) ~= nil

		return matchAtStart or matchAfterDir
	else
		return filepath:match(glob.pattern) ~= nil
	end
end

local function isIgnored(ignoreData: GitignoreData, filepath: string, isDirectory: boolean)
	local matched, ignored = false, false

	local relativePath = path.format(path.relative(ignoreData.location, filepath))

	for _, ignore in ignoreData.ignores do
		if matchesGlob(ignore, relativePath, isDirectory) then
			matched = true
			ignored = true
			break
		end
	end

	if ignored then
		for _, whitelist in ignoreData.whitelists do
			if matchesGlob(whitelist, filepath, isDirectory) then
				matched = true
				ignored = false
				break
			end
		end
	end

	if not matched and ignoreData.next then
		return isIgnored(ignoreData.next, filepath, isDirectory)
	end

	return ignored
end

--- Checks whether the given file matches an ignore
function IgnoreResolver.isIgnoredFile(self: IgnoreResolver, filepath: path.path)
	local directory = if #filepath.parts > 0 then path.dirname(filepath) else nil
	assert(directory ~= nil, "filepath has no directory!")

	local ignoreData = self:_readIgnoreRecursive(directory)
	return isIgnored(ignoreData, path.format(filepath), false)
end

function IgnoreResolver.isIgnoredDirectory(self: IgnoreResolver, directorypath: path.path)
	-- Hardcode: skip the .git directory
	local basename = path.basename(directorypath)
	if basename == ".git" then
		return true
	end

	local parentDirectory = if basename then path.dirname(directorypath) else nil
	if parentDirectory then
		local ignoreData = self:_readIgnoreRecursive(parentDirectory)
		return isIgnored(ignoreData, path.format(directorypath), true)
	else
		return false
	end
end

function IgnoreResolver._readIgnoreRecursive(self: IgnoreResolver, directory: string)
	if self._ignoreCache[directory] ~= nil then
		return self._ignoreCache[directory]
	end

	local parentPath = if path.basename(directory) then path.dirname(directory) else nil
	local baseIgnores = if parentPath then self:_readIgnoreRecursive(parentPath) else nil
	local gitignorePath = path.join(directory, ".gitignore")

	local exists, fileType = pcall(fs.type, gitignorePath)

	if exists and fileType == "file" then
		local myIgnoreData = parseGitignore(gitignorePath)

		if #myIgnoreData.ignores > 0 or #myIgnoreData.whitelists > 0 then
			myIgnoreData.next = baseIgnores
			baseIgnores = myIgnoreData
		end
	end

	if not baseIgnores then
		baseIgnores = { location = directory, ignores = {}, whitelists = {}, next = nil } :: GitignoreData
	end
	assert(baseIgnores, "Luau")

	self._ignoreCache[directory] = baseIgnores
	return baseIgnores
end

return IgnoreResolver
