local crc32 = require("../extern/unzip/crc")

local LOCAL_FILE_HEADER_SIGNATURE = 0x04034B50
local CENTRAL_DIRECTORY_SIGNATURE = 0x02014B50
local END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054B50
local ZIP_VERSION = 20
local UTF8_FLAG = 0x0800
local MAX_U16 = 0xFFFF
local MAX_U32 = 0xFFFFFFFF

export type Entry = {
	contents: buffer,
	name: string,
}

type ArchiveEntry = Entry & {
	crc: number,
	localOffset: number,
	nameBytes: buffer,
}

local function checkU16(value: number, description: string)
	assert(value >= 0 and value <= MAX_U16, `{description} exceeds the ZIP format limit`)
end

local function checkU32(value: number, description: string)
	assert(value >= 0 and value <= MAX_U32, `{description} exceeds the ZIP format limit`)
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

local function write(entries: { Entry }): buffer
	checkU16(#entries, "Number of archive entries")

	local archiveEntries: { ArchiveEntry } = {}
	local archiveSize = 22
	for _, entry in entries do
		local nameBytes = buffer.fromstring(entry.name)
		local nameLength = buffer.len(nameBytes)
		local contentLength = buffer.len(entry.contents)
		checkU16(nameLength, `Archive path '{entry.name}'`)
		checkU32(contentLength, `Archive file '{entry.name}'`)
		archiveSize += 30 + nameLength + contentLength + 46 + nameLength

		table.insert(archiveEntries, {
			contents = entry.contents,
			crc = crc32(entry.contents),
			localOffset = 0,
			name = entry.name,
			nameBytes = nameBytes,
		})
	end
	checkU32(archiveSize, "Archive size")

	local archive = buffer.create(archiveSize)
	local offset = 0
	for _, entry in archiveEntries do
		entry.localOffset = offset
		offset = writeLocalFileHeader(archive, offset, entry)
	end

	local directoryOffset = offset
	for _, entry in archiveEntries do
		offset = writeCentralDirectoryEntry(archive, offset, entry)
	end
	local directorySize = offset - directoryOffset
	writeEndOfCentralDirectory(archive, offset, #archiveEntries, directorySize, directoryOffset)
	offset += 22
	assert(offset == archiveSize, "Internal error while building ZIP archive")

	return archive
end

return table.freeze({
	write = write,
})
