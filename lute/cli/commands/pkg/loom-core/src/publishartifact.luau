local fs = require("@std/fs")
local path = require("@std/path")
local zipWriter = require("./zipwriter")

-- Every entry below content_root is included. The root manifest is 
-- preserved with an `.orig` suffix while the generated manifest takes 
-- its original path.
type PublishableFile = zipWriter.Entry

export type BuildOptions = {
	contentRoot: string?,
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
		local isLinkedDirectory = child.type == "link" and pcall(fs.listDirectory, childPath)
		if child.type == "dir" or isLinkedDirectory then
			local childParts = table.clone(parts)
			table.insert(childParts, child.name)
			collectFiles(childPath, childParts, entries, names)
		elseif child.type == "file" or child.type == "link" then
			local entryParts = table.clone(parts)
			table.insert(entryParts, child.name)
			local name = if #parts == 0 and child.name == "loom.config.luau"
				then "loom.config.luau.orig"
				else archiveName(entryParts)
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

	collectFiles(contentDirectory, {}, entries, names)
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

return table.freeze({
	build = build,
})
