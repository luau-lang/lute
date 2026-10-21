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

local function collectFiles(
	directory: path.Path,
	parts: { string },
	entries: { PublishableFile },
	names: { [string]: boolean }
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
				collectFiles(childPath, childParts, entries, names)
			end
		elseif child.type == "file" and not isExcludedFile(child.name) then
			local entryParts = table.clone(parts)
			table.insert(entryParts, child.name)
			local name = archiveName(entryParts)
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

local function build(packageDirectory: string, generatedManifest: string): buffer
	local root = path.resolve(packageDirectory)
	assert(fs.type(root) == "dir", `Package directory is not a directory: {path.format(root)}`)

	local entries: { PublishableFile } = {}
	local names: { [string]: boolean } = {}
	local generatedContents = buffer.fromstring(generatedManifest)
	table.insert(entries, {
		contents = generatedContents,
		name = "loom.config.luau",
	})
	names["loom.config.luau"] = true

	collectFiles(root, {}, entries, names)
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

return table.freeze({
	build = build,
})
