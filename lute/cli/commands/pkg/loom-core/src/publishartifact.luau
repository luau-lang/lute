local fs = require("@std/fs")
local path = require("@std/path")
local parseIgnores = require("@commands/lib/parseIgnores")
local zipWriter = require("./zipwriter")

-- Entries below content_root are included according to the optional files
-- filter. The root manifest is preserved with an `.orig` suffix while the
-- generated manifest is always at root
type PublishableFile = zipWriter.Entry

type FilePattern = {
	glob: parseIgnores.Glob,
	negated: boolean,
}

type FilesFilter = {
	hasInclude: boolean,
	patterns: { FilePattern },
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

local function relativePath(parts: { string }): string
	return path.format({
		parts = parts,
		absolute = false,
	})
end

local function patternMatchesPath(pattern: FilePattern, parts: { string }): boolean
	if parseIgnores.matchesGlob(pattern.glob, relativePath(parts), false) then
		return true
	end

	-- A pattern matching a directory also matches every file beneath it. This
	-- gives patterns such as `foo`, `foo/`, and `foo/**` their gitignore
	-- directory semantics without preventing a later ! pattern from restoring a
	-- descendant.
	local ancestorParts: { string } = {}
	for index, part in parts do
		if index == #parts then
			break
		end
		table.insert(ancestorParts, part)
		if parseIgnores.matchesGlob(pattern.glob, relativePath(ancestorParts), true) then
			return true
		end
	end

	return false
end

local function parseFilesFilter(patterns: { string }?): FilesFilter?
	if patterns == nil then
		return nil
	end

	local filter: FilesFilter = {
		hasInclude = false,
		patterns = {},
	}
	for _, pattern in patterns do
		local negated = string.sub(pattern, 1, 1) == "!"
		local globPattern = if negated then string.sub(pattern, 2) else pattern
		if not negated then
			filter.hasInclude = true
		end
		-- parseIgnoreContents keeps glob compilation private, so parse this one
		-- pattern as an ignore and apply files' inverse inclusion semantics below.
		local parsed = parseIgnores.parseIgnoreContents(".", { globPattern })
		table.insert(filter.patterns, {
			glob = parsed.ignores[1],
			negated = negated,
		})
	end
	return filter
end

local function includesFile(filter: FilesFilter?, parts: { string }): boolean
	if filter == nil then
		return true
	end

	-- A files list containing a positive pattern is an allowlist, while
	-- a list containing only exclusions starts by including every file.
	local included = not filter.hasInclude
	for _, pattern in filter.patterns do
		if patternMatchesPath(pattern, parts) then
			included = not pattern.negated
		end
	end
	return included
end

local function collectFiles(
	directory: path.Path,
	parts: { string },
	entries: { PublishableFile },
	names: { [string]: boolean },
	filter: FilesFilter?
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
			collectFiles(childPath, childParts, entries, names, filter)
		elseif child.type == "file" or child.type == "link" then
			local entryParts = table.clone(parts)
			table.insert(entryParts, child.name)
			if not includesFile(filter, entryParts) then
				continue
			end
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

	collectFiles(contentDirectory, {}, entries, names, parseFilesFilter(files))
	table.sort(entries, function(a: PublishableFile, b: PublishableFile)
		return a.name < b.name
	end)

	return zipWriter.write(entries)
end

return table.freeze({
	build = build,
})
