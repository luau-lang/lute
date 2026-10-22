local fs = require("@std/fs")
local path = require("@std/path")
local filesFilter = require("./filesfilter")
local zipWriter = require("./zipwriter")

local PACKAGE_MANIFEST = "loom.config.luau"
local ORIGINAL_PACKAGE_MANIFEST = PACKAGE_MANIFEST .. ".orig"

-- The package-root manifest is preserved with an `.orig` suffix while the
-- generated manifest is always at root.
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

local function hasHiddenPart(parts: { string }): boolean
	for _, part in parts do
		if string.sub(part, 1, 1) == "." then
			return true
		end
	end
	return false
end

local function collectFiles(
	directory: path.Path,
	parts: { string },
	entries: { PublishableFile },
	names: { [string]: boolean },
	filter: filesFilter.State,
	originalManifestPathString: string
)
	local children = fs.listDirectory(directory)
	table.sort(children, function(a: fs.DirectoryEntry, b: fs.DirectoryEntry)
		return a.name < b.name
	end)

	for _, child in children do
		local childPath = path.join(directory, child.name)
		assert(child.type ~= "link", "Symlinks in project source are not supported")
		if child.type == "dir" then
			local childParts = table.clone(parts)
			table.insert(childParts, child.name)
			collectFiles(childPath, childParts, entries, names, filter, originalManifestPathString)
		elseif child.type == "file" or child.type == "link" then
			if path.format(childPath) == originalManifestPathString then
				continue
			end
			local entryParts = table.clone(parts)
			table.insert(entryParts, child.name)
			if not filesFilter.includes(filter, entryParts, false) then
				continue
			end
			if hasHiddenPart(entryParts) and not filesFilter.explicitlyIncludes(filter, entryParts, false) then
				continue
			end
			local name = archiveName(entryParts)
			assert(
				name ~= PACKAGE_MANIFEST,
				`Cannot publish file '{name}': archive path is reserved for the generated package manifest; rename the source file`
			)
			assert(not names[name], `Duplicate archive path: '{name}'`)
			names[name] = true

			table.insert(entries, {
				contents = buffer.fromstring(fs.readFileToString(childPath)),
				name = name,
			})
		end
	end
end

local function resolveContentDirectory(root: path.Path, contentRoot: string?): path.Path
	if contentRoot == nil then
		return root
	end

	assert(not path.isAbsolute(contentRoot), "'content_root' must be relative to the package directory")
	local normalized = path.normalize(contentRoot)
	assert(normalized.parts[1] ~= "..", "'content_root' must stay inside the package directory")
	return path.resolve(path.format(root), normalized)
end

local function build(
	packageDirectory: string,
	sourceManifestPath: string,
	generatedManifest: string,
	options: BuildOptions?
): buffer
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
		name = PACKAGE_MANIFEST,
	})
	names[PACKAGE_MANIFEST] = true

	-- Preserving the old source manifest for metadata purposes
	local originalManifestPath = path.resolve(sourceManifestPath)
	local originalManifestPathString = path.format(originalManifestPath)
	local originalManifestType = fs.type(originalManifestPath)
	assert(originalManifestType ~= "link", "Symlinks in project source are not supported")
	assert(originalManifestType == "file", `Package manifest is not a file: {originalManifestPathString}`)
	table.insert(entries, {
		contents = buffer.fromstring(fs.readFileToString(originalManifestPath)),
		name = ORIGINAL_PACKAGE_MANIFEST,
	})
	names[ORIGINAL_PACKAGE_MANIFEST] = true

	collectFiles(contentDirectory, {}, entries, names, filesFilter.new(files), originalManifestPathString)
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

return table.freeze({
	build = build,
})
