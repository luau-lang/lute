local fs = require("@std/fs")
local path = require("@std/path")
local filesFilter = require("./filesfilter")
local zipWriter = require("./zipwriter")

local PACKAGE_MANIFEST = "loom.config.luau"

type PublishableFile = zipWriter.Entry

type CollectedFile = {
	path: path.Path,
	name: string,
}

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
	files: { CollectedFile },
	names: { [string]: boolean },
	filter: filesFilter.State,
	sourceManifestPathString: string
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
			collectFiles(childPath, childParts, files, names, filter, sourceManifestPathString)
		elseif child.type == "file" or child.type == "link" then
			if path.format(childPath) == sourceManifestPathString then
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

			table.insert(files, {
				path = childPath,
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

local function collectPublishableFiles(
	packageDirectory: string,
	sourceManifestPath: string,
	options: BuildOptions?
): { CollectedFile }
	local root = path.resolve(packageDirectory)
	assert(fs.type(root) == "dir", `Package directory is not a directory: {path.format(root)}`)
	local contentRoot = if options == nil then nil else options.contentRoot
	local files = if options == nil then nil else options.files
	local contentDirectory = resolveContentDirectory(root, contentRoot)
	assert(
		fs.type(contentDirectory) == "dir",
		`Package content root is not a directory: {path.format(contentDirectory)}`
	)

	local publishableFiles: { CollectedFile } = {}
	local names = { [PACKAGE_MANIFEST] = true }
	local sourceManifestPathString = path.format(path.resolve(sourceManifestPath))
	collectFiles(contentDirectory, {}, publishableFiles, names, filesFilter.new(files), sourceManifestPathString)
	return publishableFiles
end

local function build(
	packageDirectory: string,
	sourceManifestPath: string,
	generatedManifest: string,
	options: BuildOptions?
): buffer
	local entries: { PublishableFile } = {}
	table.insert(entries, {
		contents = buffer.fromstring(generatedManifest),
		name = PACKAGE_MANIFEST,
	})
	for _, file in collectPublishableFiles(packageDirectory, sourceManifestPath, options) do
		table.insert(entries, {
			contents = buffer.fromstring(fs.readFileToString(file.path)),
			name = file.name,
		})
	end
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

local function list(packageDirectory: string, sourceManifestPath: string, options: BuildOptions?): { string }
	local names = { PACKAGE_MANIFEST }
	for _, file in collectPublishableFiles(packageDirectory, sourceManifestPath, options) do
		table.insert(names, file.name)
	end
	table.sort(names)
	return names
end

return table.freeze({
	build = build,
	list = list,
})
