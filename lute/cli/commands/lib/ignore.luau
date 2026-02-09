local fs = require("@std/fs")
local path = require("@std/path")
local parseIgnores = require("./parseIgnores")
local matchesGlob = parseIgnores.matchesGlob
local parseGitignore = parseIgnores.parseGitignore

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
