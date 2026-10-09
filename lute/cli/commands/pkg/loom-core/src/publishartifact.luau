-- Builds deterministic ZIP artifacts for package publishing.
local crc32 = require("../extern/unzip/crc")
local fs = require("@std/fs")
local path = require("@std/path")

local LOCAL_FILE_HEADER_SIGNATURE = 0x04034B50
local CENTRAL_DIRECTORY_SIGNATURE = 0x02014B50
local END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054B50
local ZIP_VERSION = 20
local UTF8_FLAG = 0x0800
local MAX_U16 = 0xFFFF
local MAX_U32 = 0xFFFFFFFF

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

type ArchiveEntry = {
	contents: buffer,
	crc: number,
	localOffset: number,
	name: string,
	nameBytes: buffer,
}

local function checkU16(value: number, description: string)
	assert(value >= 0 and value <= MAX_U16, `{description} exceeds the ZIP format limit`)
end

local function checkU32(value: number, description: string)
	assert(value >= 0 and value <= MAX_U32, `{description} exceeds the ZIP format limit`)
end

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
	entries: { ArchiveEntry },
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
				crc = crc32(contents),
				localOffset = 0,
				name = name,
				nameBytes = buffer.fromstring(name),
			})
		end
	end
end

local function writeLocalFileHeader(output: buffer, offset: number, entry: ArchiveEntry): number
	local nameLength = buffer.len(entry.nameBytes)
	local contentLength = buffer.len(entry.contents)

	buffer.writeu32(output, offset, LOCAL_FILE_HEADER_SIGNATURE)
	buffer.writeu16(output, offset + 4, ZIP_VERSION)
	buffer.writeu16(output, offset + 6, UTF8_FLAG)
	buffer.writeu16(output, offset + 8, 0) -- stored, without compression
	buffer.writeu32(output, offset + 10, 0) -- fixed DOS timestamp for reproducibility
	buffer.writeu32(output, offset + 14, entry.crc)
	buffer.writeu32(output, offset + 18, contentLength)
	buffer.writeu32(output, offset + 22, contentLength)
	buffer.writeu16(output, offset + 26, nameLength)
	buffer.writeu16(output, offset + 28, 0)
	buffer.copy(output, offset + 30, entry.nameBytes)
	buffer.copy(output, offset + 30 + nameLength, entry.contents)

	return offset + 30 + nameLength + contentLength
end

local function writeCentralDirectoryEntry(output: buffer, offset: number, entry: ArchiveEntry): number
	local nameLength = buffer.len(entry.nameBytes)
	local contentLength = buffer.len(entry.contents)

	buffer.writeu32(output, offset, CENTRAL_DIRECTORY_SIGNATURE)
	buffer.writeu16(output, offset + 4, ZIP_VERSION)
	buffer.writeu16(output, offset + 6, ZIP_VERSION)
	buffer.writeu16(output, offset + 8, UTF8_FLAG)
	buffer.writeu16(output, offset + 10, 0) -- stored, without compression
	buffer.writeu32(output, offset + 12, 0) -- fixed DOS timestamp for reproducibility
	buffer.writeu32(output, offset + 16, entry.crc)
	buffer.writeu32(output, offset + 20, contentLength)
	buffer.writeu32(output, offset + 24, contentLength)
	buffer.writeu16(output, offset + 28, nameLength)
	buffer.writeu16(output, offset + 30, 0) -- extra field length
	buffer.writeu16(output, offset + 32, 0) -- comment length
	buffer.writeu16(output, offset + 34, 0) -- disk number
	buffer.writeu16(output, offset + 36, 0) -- internal attributes
	buffer.writeu32(output, offset + 38, 0) -- external attributes
	buffer.writeu32(output, offset + 42, entry.localOffset)
	buffer.copy(output, offset + 46, entry.nameBytes)

	return offset + 46 + nameLength
end

local function writeEndOfCentralDirectory(
	output: buffer,
	offset: number,
	entryCount: number,
	size: number,
	directoryOffset: number
)
	buffer.writeu32(output, offset, END_OF_CENTRAL_DIRECTORY_SIGNATURE)
	buffer.writeu16(output, offset + 4, 0)
	buffer.writeu16(output, offset + 6, 0)
	buffer.writeu16(output, offset + 8, entryCount)
	buffer.writeu16(output, offset + 10, entryCount)
	buffer.writeu32(output, offset + 12, size)
	buffer.writeu32(output, offset + 16, directoryOffset)
	buffer.writeu16(output, offset + 20, 0) -- archive comment length
end

local function build(packageDirectory: string, generatedManifest: string): buffer
	local root = path.resolve(packageDirectory)
	assert(fs.type(root) == "dir", `Package directory is not a directory: {path.format(root)}`)

	local entries: { ArchiveEntry } = {}
	local names: { [string]: boolean } = {}
	local generatedContents = buffer.fromstring(generatedManifest)
	table.insert(entries, {
		contents = generatedContents,
		crc = crc32(generatedContents),
		localOffset = 0,
		name = "loom.config.luau",
		nameBytes = buffer.fromstring("loom.config.luau"),
	})
	names["loom.config.luau"] = true

	collectFiles(root, {}, entries, names)
	table.sort(entries, function(a: ArchiveEntry, b: ArchiveEntry)
		return a.name < b.name
	end)

	checkU16(#entries, "Number of archive entries")
	local archiveSize = 22
	for _, entry in entries do
		local nameLength = buffer.len(entry.nameBytes)
		local contentLength = buffer.len(entry.contents)
		checkU16(nameLength, `Archive path '{entry.name}'`)
		checkU32(contentLength, `Archive file '{entry.name}'`)
		archiveSize += 30 + nameLength + contentLength + 46 + nameLength
	end
	checkU32(archiveSize, "Archive size")

	local archive = buffer.create(archiveSize)
	local offset = 0
	for _, entry in entries do
		entry.localOffset = offset
		offset = writeLocalFileHeader(archive, offset, entry)
	end

	local directoryOffset = offset
	for _, entry in entries do
		offset = writeCentralDirectoryEntry(archive, offset, entry)
	end
	local directorySize = offset - directoryOffset
	writeEndOfCentralDirectory(archive, offset, #entries, directorySize, directoryOffset)
	offset += 22
	assert(offset == archiveSize, "Internal error while building ZIP archive")

	return archive
end

return table.freeze({
	build = build,
})
