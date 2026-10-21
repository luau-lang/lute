local glob = require("@batteries/glob")
local fs = require("@std/fs")
local path = require("@std/path")
local zipWriter = require("./zipwriter")

local EXCLUDED_DIRECTORIES: { [string]: boolean } = {
	[".bzr"] = true,
	[".git"] = true,
	[".hg"] = true,
	[".loom"] = true,
	[".svn"] = true,
	["_darcs"] = true,
	["CVS"] = true,
	["Packages"] = true,
}

local EXCLUDED_FILES: { [string]: boolean } = {
	[".git"] = true,
	[".gitattributes"] = true,
	[".gitignore"] = true,
	[".gitmodules"] = true,
	[".hgignore"] = true,
	[".hgrc"] = true,
	[".svnignore"] = true,
	["loom.config.luau"] = true,
	["loom.lock.luau"] = true,
}

type PublishableFile = zipWriter.Entry

export type BuildOptions = {
	contentRoot: string?,
	files: { string }?,
}

local function assertSafePathPart(part: string)
	assert(part ~= "" and part ~= "." and part ~= "..", `Cannot add unsafe archive path component '{part}'`)
	assert(
		not string.find(part, "/", 1, true)
			and not string.find(part, "\\", 1, true)
			and not string.find(part, "\0", 1, true),
		`Cannot add unsafe archive path component '{part}'`
	)
end

local function archiveName(parts: { string }): string
	for _, part in parts do
		assertSafePathPart(part)
	end

	local name = table.concat(parts, "/")
	assert(#name > 0 and string.sub(name, 1, 1) ~= "/", `Cannot add unsafe archive path '{name}'`)
	return name
end

local function isExcludedFile(name: string): boolean
	return EXCLUDED_FILES[name] == true
end

local function matchesFilePattern(pattern: string, name: string): boolean
	local directoryPattern = string.sub(pattern, -1) == "/"
	if directoryPattern then
		pattern = string.sub(pattern, 1, -2)
	end

	local anchored = string.sub(pattern, 1, 1) == "/"
	if anchored then
		pattern = string.sub(pattern, 2)
	end
	if not anchored and not string.find(pattern, "/", 1, true) then
		pattern = "**/" .. pattern
	end

	if not directoryPattern and glob.match(pattern, name) then
		return true
	end

	local parts = string.split(name, "/")
	for index = 1, #parts - 1 do
		if glob.match(pattern, table.concat(parts, "/", 1, index)) then
			return true
		end
	end
	return false
end

-- ordered gitignore-style include/exclude convention: regular
-- patterns include files and patterns prefixed with `!` exclude them
local function isIncludedByFiles(files: { string }?, name: string): boolean
	if files == nil or #files == 0 then
		return true
	end

	local included = false
	for _, entry in files do
		local excluded = string.sub(entry, 1, 1) == "!"
		local pattern = if excluded then string.sub(entry, 2) else entry
		if matchesFilePattern(pattern, name) then
			included = not excluded
		end
	end
	return included
end

local function collectFiles(
	directory: path.Path,
	parts: { string },
	entries: { PublishableFile },
	names: { [string]: boolean },
	files: { string }?
)
	local children = fs.listDirectory(directory)
	table.sort(children, function(a: fs.DirectoryEntry, b: fs.DirectoryEntry)
		return a.name < b.name
	end)

	for _, child in children do
		local childPath = path.join(directory, child.name)
		if child.type == "dir" then
			if not EXCLUDED_DIRECTORIES[child.name] then
				local childParts = table.clone(parts)
				table.insert(childParts, child.name)
				collectFiles(childPath, childParts, entries, names, files)
			end
		elseif child.type == "file" and not isExcludedFile(child.name) then
			local entryParts = table.clone(parts)
			table.insert(entryParts, child.name)
			local name = archiveName(entryParts)
			if isIncludedByFiles(files, name) then
				assert(not names[name], `Duplicate archive path: '{name}'`)
				names[name] = true

				local contents = buffer.fromstring(fs.readFileToString(childPath))
				table.insert(entries, {
					contents = contents,
					name = name,
				})
			end
		end
	end
end

local function resolveContentDirectory(root: path.Path, contentRoot: string?): path.Path
	if contentRoot == nil then
		return root
	end

	assert(not path.posix.isAbsolute(contentRoot), "'content_root' must be relative to the package directory")
	local normalized = path.posix.normalize(contentRoot)
	assert(normalized.parts[1] ~= "..", "'content_root' must stay inside the package directory")
	return path.resolve(
		root,
		path.posix.format({
			parts = normalized.parts,
			absolute = false,
		})
	)
end

local function build(packageDirectory: string, generatedManifest: string, options: BuildOptions?): buffer
	local root = path.resolve(packageDirectory)
	assert(fs.type(root) == "dir", `Package directory is not a directory: {path.format(root)}`)
	local contentRoot = if options == nil then nil else options.contentRoot
	local files = if options == nil then nil else options.files
	local contentDirectory = resolveContentDirectory(root, contentRoot)
	assert(
		fs.type(contentDirectory) == "dir",
		`Package content root is not a directory: {path.format(contentDirectory)}`
	)

	local entries: { PublishableFile } = {}
	local names: { [string]: boolean } = {}
	local generatedContents = buffer.fromstring(generatedManifest)
	table.insert(entries, {
		contents = generatedContents,
		name = "loom.config.luau",
	})
	names["loom.config.luau"] = true

	collectFiles(contentDirectory, {}, entries, names, files)
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

return table.freeze({
	build = build,
})
