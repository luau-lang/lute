local inflate = require("@self/inflate")
local validateCrc = require("@self/utils/validate_crc")
local path = require("@self/utils/path")

-- The maximum supported PKZIP format specification version that we support
local MAX_SUPPORTED_PKZIP_VERSION = 63

-- Little endian constant signatures used in the ZIP file format
local SIGNATURES = table.freeze({
	-- Marks the beginning of each file in the ZIP
	LOCAL_FILE = 0x04034b50,
	-- Marks the start of a data descriptor
	DATA_DESCRIPTOR = 0x08074b50,
	-- Marks entries in the central directory
	CENTRAL_DIR = 0x02014b50,
	-- Marks the end of the central directory
	END_OF_CENTRAL_DIR = 0x06054b50,
})

-- Decompression routines for each supported compression method
local DECOMPRESSION_ROUTINES: { [number]: { name: CompressionMethod, decompress: (buffer, number, validateCrc.CrcValidationOptions) -> buffer } } =
	{
		-- `STORE` decompression method - No compression
		[0x00] = {
			name = "STORE" :: CompressionMethod,
			decompress = function(buf, _, validation): buffer
				validateCrc(buf, validation)
				return buf
			end,
		},

		-- `DEFLATE` decompression method - Compressed raw deflate chunks
		[0x08] = {
			name = "DEFLATE" :: CompressionMethod,
			decompress = function(buf, uncompressedSize, validation): buffer
				local decompressed = inflate(buf, uncompressedSize)
				validateCrc(decompressed, validation)
				return decompressed
			end,
		},
	}

-- Set of placeholder entry properties for incompatible entries
local EMPTY_PROPERTIES: ZipEntryProperties = table.freeze({
	versionMadeBy = 0,
	compressedSize = 0,
	size = 0,
	attributes = 0,
	timestamp = 0,
	crc = 0,
})

-- Lookup table for the OS that created the ZIP
local MADE_BY_OS_LOOKUP: { [number]: MadeByOS } = {
	[0x0] = "FAT",
	[0x1] = "AMIGA",
	[0x2] = "VMS",
	[0x3] = "UNIX",
	[0x4] = "VM/CMS",
	[0x5] = "Atari ST",
	[0x6] = "OS/2",
	[0x7] = "MAC",
	[0x8] = "Z-System",
	[0x9] = "CP/M",
	[0xa] = "NTFS",
	[0xb] = "MVS",
	[0xc] = "VSE",
	[0xd] = "Acorn RISCOS",
	[0xe] = "VFAT",
	[0xf] = "Alternate MVS",
	[0x10] = "BeOS",
	[0x11] = "TANDEM",
	[0x12] = "OS/400",
	[0x13] = "OS/X",
}

--[=[
	@class ZipEntry
	
	A single entry (a file or a directory) in a ZIP file, and its properties.
]=]
local ZipEntry = {}

--[=[
	@interface ZipEntry
	@within ZipEntry

	@field name string -- File path within ZIP, '/' suffix indicates directory
	@field versionMadeBy { software: string, os: MadeByOS } -- Version of software and OS that created the ZIP
	@field compressedSize number -- Compressed size in bytes
	@field size number -- Uncompressed size in bytes
	@field offset number -- Absolute position of local header in ZIP
	@field timestamp number -- MS-DOS format timestamp
	@field method CompressionMethod -- Method used to compress the file
	@field crc number -- CRC32 checksum of the uncompressed data
	@field isDirectory boolean -- Whether the entry is a directory or not
	@field isText boolean -- Whether the entry is plain ASCII text or binary
	@field attributes number -- File attributes
	@field parent ZipEntry? -- Parent directory entry, `nil` if entry is root
	@field children { ZipEntry } -- Children of the entry, if it was a directory, empty array for files
]=]
export type ZipEntry = typeof(setmetatable({} :: ZipEntryInner, { __index = ZipEntry }))
type ZipEntryInner = {
	name: string,

	versionMadeBy: {
		software: string,
		os: MadeByOS,
	},

	compressedSize: number,
	size: number,
	offset: number,
	timestamp: number,
	method: CompressionMethod,
	crc: number,
	isDirectory: boolean,
	isText: boolean,
	attributes: number,
	parent: ZipEntry?,
	children: { ZipEntry },
}

-- stylua: ignore
--[=[
	@within ZipEntry	
	@type MadeByOS "FAT" | "AMIGA" | "VMS" | "UNIX" | "VM/CMS" | "Atari ST" | "OS/2" | "MAC" | "Z-System" | "CP/M" | "NTFS" | "MVS" | "VSE" | "Acorn RISCOS" | "VFAT" | "Alternate MVS" | "BeOS" | "TANDEM" | "OS/400" | "OS/X" | "Unknown"     

	The OS that created the ZIP.
]=]
export type MadeByOS =
	| "FAT"           -- 0x0; MS-DOS and OS/2 (FAT / VFAT / FAT32 file systems)
	| "AMIGA"         -- 0x1; Amiga
	| "VMS"           -- 0x2; OpenVMS
	| "UNIX"          -- 0x3; Unix
	| "VM/CMS"        -- 0x4; VM/CMS
	| "Atari ST"      -- 0x5; Atari ST
	| "OS/2"          -- 0x6; OS/2 HPFS
	| "MAC"           -- 0x7; Macintosh
	| "Z-System"      -- 0x8; Z-System
	| "CP/M"          -- 0x9; Original CP/M
	| "NTFS"          -- 0xa; Windows NTFS
	| "MVS"           -- 0xb; OS/390 & VM/ESA
	| "VSE"           -- 0xc; VSE
	| "Acorn RISCOS"  -- 0xd; Acorn RISCOS
	| "VFAT"          -- 0xe; VFAT
	| "Alternate MVS" -- 0xf; Alternate MVS
	| "BeOS"          -- 0x10; BeOS
	| "TANDEM"        -- 0x11; Tandem
	| "OS/400"        -- 0x12; OS/400
	| "OS/X"          -- 0x13; Darwin
	| "Unknown"       -- 0x14 - 0xff; Unused

--[=[
	@within ZipEntry
	@type CompressionMethod "STORE" | "DEFLATE"

	The method used to compress the file:
	- `STORE` - No compression
	- `DEFLATE` - Compressed raw deflate chunks
]=]
export type CompressionMethod = "STORE" | "DEFLATE"

--[=[
	@interface ZipEntryProperties
	@within ZipEntry
	@private

	A set of properties that describe a ZIP entry. Used internally for construction of 
	[ZipEntry] objects.

	@field versionMadeBy number -- Version of software and OS that created the ZIP
	@field compressedSize number -- Compressed size in bytes
	@field size number -- Uncompressed size in bytes
	@field attributes number -- File attributes
	@field timestamp number -- MS-DOS format timestamp
	@field method CompressionMethod? -- Method used
	@field crc number -- CRC32 checksum of the uncompressed data
]=]
type ZipEntryProperties = {
	versionMadeBy: number,
	compressedSize: number,
	size: number,
	attributes: number,
	timestamp: number,
	method: CompressionMethod?,
	crc: number,
}

--[=[
	@within ZipEntry
	@function new
	@private

	@param offset number -- Offset of the entry in the ZIP file
	@param name string -- File path within ZIP, '/' suffix indicates directory
	@param properties ZipEntryProperties -- Properties of the entry
	@return ZipEntry -- The constructed entry
]=]
function ZipEntry.new(offset: number, name: string, properties: ZipEntryProperties): ZipEntry
	local versionMadeByOS = bit32.rshift(properties.versionMadeBy, 8)
	local versionMadeByVersion = bit32.band(properties.versionMadeBy, 0x00ff)

	return setmetatable(
		{
			name = name,
			versionMadeBy = {
				software = string.format("%d.%d", versionMadeByVersion / 10, versionMadeByVersion % 10),
				os = MADE_BY_OS_LOOKUP[versionMadeByOS] :: MadeByOS,
			},
			compressedSize = properties.compressedSize,
			size = properties.size,
			offset = offset,
			timestamp = properties.timestamp,
			method = properties.method,
			crc = properties.crc,
			isDirectory = string.sub(name, -1) == "/",
			attributes = properties.attributes,
			parent = nil,
			children = {},
		} :: ZipEntryInner,
		{ __index = ZipEntry }
	)
end

--[=[
	@within ZipEntry
	@method isSymlink

	Returns whether the entry is a symlink.

	@return boolean
]=]
function ZipEntry.isSymlink(self: ZipEntry): boolean
	return bit32.band(self.attributes, 0xA0000000) == 0xA0000000
end

--[=[
	@within ZipEntry
	@method getPath

	Resolves the path of the entry based on its relationship with other entries. It is recommended to use this 
	method instead of accessing the `name` property directly, although they should be equivalent.

	> [!WARNING]
	> Never use this method when extracting files from the ZIP, since it can contain absolute paths
	> (say `/etc/passwd`) referencing directories outside the current directory (say `/tmp/extracted`),
	> causing unintended overwrites of files.

	@return string -- The path of the entry
]=]
function ZipEntry.getPath(self: ZipEntry): string
	if self.name == "/" then
		return "/"
	end

	-- Get just the entry name without the path
	local name = string.match(self.name, "([^/]+)/?$") or self.name

	if not self.parent or self.parent.name == "/" then
		return self.name
	end

	-- Combine parent path with entry name
	local path = string.gsub(self.parent:getPath() .. name, "//+", "/")
	return path
end

--[=[
	@within ZipEntry
	@method getSafePath

	Resolves the path of the entry based on its relationship with other entries and returns it
	only if it is safe to use for extraction, otherwise returns `nil`.

	@return string? -- Optional path of the entry if it was safe
]=]
function ZipEntry.getSafePath(self: ZipEntry): string?
	local pathStr = self:getPath()

	if path.isSafe(pathStr) then
		return pathStr
	end

	return nil
end

--[=[
	@within ZipEntry
	@method sanitizePath

	Sanitizes the path of the entry, potentially losing information, but ensuring the path is
	safe to use for extraction.

	@return string -- The sanitized path of the entry
]=]
function ZipEntry.sanitizePath(self: ZipEntry): string
	local pathStr = self:getPath()
	return path.sanitize(pathStr)
end

--[=[
	@within ZipEntry
	@method compressionEfficiency 

	Calculates the compression efficiency of the entry, or `nil` if the entry is a directory.

	Uses the formula: `round((1 - compressedSize / size) * 100)` and outputs a percentage.

	@return number? -- Optional compression efficiency of the entry
]=]
function ZipEntry.compressionEfficiency(self: ZipEntry): number?
	if self.size == 0 or self.compressedSize == 0 then
		return nil
	end

	local ratio = 1 - self.compressedSize / self.size
	return math.round(ratio * 100)
end

--[=[
	@within ZipEntry
	@method isFile

	Returns whether the entry is a file, i.e., not a directory or symlink.

	@return boolean -- Whether the entry is a file
]=]
function ZipEntry.isFile(self: ZipEntry): boolean
	return not (self.isDirectory and self:isSymlink())
end

--[=[
	@within ZipEntry
	@interface UnixMode

	A object representation of the UNIX mode.

	@field perms string -- The permission octal
	@field typeFlags string -- The type flags octal
]=]
export type UnixMode = { perms: string, typeFlags: string }

--[=[
	@within ZipEntry
	@method unixMode

	Parses the entry's attributes to extract a UNIX mode, represented as a [UnixMode].

	@return UnixMode? -- The UNIX mode of the entry, or `nil` if the entry is not a UNIX file
]=]
function ZipEntry.unixMode(self: ZipEntry): UnixMode?
	if self.versionMadeBy.os ~= "UNIX" then
		return nil
	end

	local mode = bit32.rshift(self.attributes, 16)
	local typeFlags = bit32.band(self.attributes, 0x1FF)
	local perms = bit32.band(mode, 0x01FF)

	return {
		perms = string.format("0o%o", perms),
		typeFlags = string.format("0o%o", typeFlags),
	}
end

--[=[
	@class ZipReader

	The main class which represents a decoded state of a ZIP file, holding references
	to its entries. This is the primary point of interaction with the ZIP file's contents.
]=]
local ZipReader = {}

--[=[
	@interface ZipReader
	@within ZipReader

	@field data buffer -- The buffer containing the raw bytes of the ZIP
	@field comment string -- Comment associated with the ZIP
	@field entries { ZipEntry } -- The decoded entries present
	@field directories { [string]: ZipEntry } -- The directories and their respective entries
	@field root ZipEntry -- The entry of the root directory
]=]
export type ZipReader = typeof(setmetatable({} :: ZipReaderInner, { __index = ZipReader }))
type ZipReaderInner = {
	data: buffer,
	comment: string,
	entries: { ZipEntry },
	directories: { [string]: ZipEntry },
	root: ZipEntry,
}

--[=[
	@within ZipReader
	@function new

	Creates a new ZipReader instance from the raw bytes of a ZIP file.
	
	**Errors if the ZIP file is invalid.**

	@param data buffer -- The buffer containing the raw bytes of the ZIP
	@return ZipReader -- The new ZipReader instance
]=]
function ZipReader.new(data): ZipReader
	local root = ZipEntry.new(0, "/", EMPTY_PROPERTIES)
	root.isDirectory = true

	local this = setmetatable(
		{
			data = data,
			entries = {},
			directories = {},
			root = root,
		} :: ZipReaderInner,
		{ __index = ZipReader }
	)

	this:parseCentralDirectory()
	this:buildDirectoryTree()
	return this
end

--[=[
	@within ZipReader
	@method findEocdPosition
	@private

	Finds the position of the End of Central Directory (EoCD) signature in the ZIP file. This
	implementation is inspired by that of [async_zip], a Rust library for parsing ZIP files
	asynchronously.

	This method involves buffered reading in reverse and reverse linear searching along those buffers 
	for the EoCD signature. As a result of the buffered approach, we reduce individual reads when compared 
	to reading every single byte sequentially, by a factor of the buffer size (4 KB by default). The buffer
	size of 4 KB was arrived at because it aligns with many systems' page sizes, and also provides a
	good balance between read efficiency (not too small), memory usage (not too large) and CPU cache
	performance.

	From my primitive benchmarks, this method is ~1.5x faster than the sequential approach.

	**Errors if the ZIP file is invalid.**

	[async_zip]: https://github.com/Majored/rs-async-zip/blob/527bda9/src/base/read/io/locator.rs#L37-L45

	@error "Could not find End of Central Directory signature"

	@return number -- The offset to the End of Central Directory (including the signature)
]=]
function ZipReader.findEocdPosition(self: ZipReader): number
	local BUFFER_SIZE = 4096
	local SIGNATURE_LENGTH = 4
	local bufSize = buffer.len(self.data)

	-- Start from the minimum possible position of EoCD (22 bytes from end)
	local position = math.max(0, bufSize - (22 + 65536) --[[ max comment size: 64 KB ]])
	local searchBuf = buffer.create(BUFFER_SIZE)

	while position < bufSize do
		local readSize = math.min(BUFFER_SIZE, bufSize - position)
		buffer.copy(searchBuf, 0, self.data, position, readSize)

		-- Search backwards through buffer for signature
		for i = readSize - 1, SIGNATURE_LENGTH - 1, -1 do
			if buffer.readu32(searchBuf, i - SIGNATURE_LENGTH + 1) == SIGNATURES.END_OF_CENTRAL_DIR then
				return position + i - SIGNATURE_LENGTH + 1
			end
		end

		-- Move position backward with overlap for cross-boundary signatures
		position += BUFFER_SIZE - SIGNATURE_LENGTH
	end

	error("Could not find End of Central Directory signature")
end

--[=[
	@within ZipReader
	@interface EocdRecord
	@private

	A parsed End of Central Directory record.

	@field diskNumber number -- The disk number
	@field diskWithCD number -- The disk number of the disk with the Central Directory
	@field cdEntries number -- The number of entries in the Central Directory
	@field totalCDEntries number -- The total number of entries in the Central Directory
	@field cdSize number -- The size of the Central Directory
	@field cdOffset number -- The offset of the Central Directory
	@field comment string -- The comment associated with the ZIP
]=]
export type EocdRecord = {
	diskNumber: number,
	diskWithCD: number,
	cdEntries: number,
	totalCDEntries: number,
	cdSize: number,
	cdOffset: number,
	comment: string,
}

--[=[
	@within ZipReader
	@method parseEocdRecord
	@private

	Parses the End of Central Directory record at the given position, usually located
	using the [ZipReader:findEocdPosition].

	**Errors if the ZIP file is invalid.**
	
	@error "Invalid Central Directory offset or size"

	@param pos number -- The offset to the End of Central Directory record
	@return EocdRecord -- Structural representation of the parsed record
]=]
function ZipReader.parseEocdRecord(self: ZipReader, pos: number): EocdRecord
	-- End of Central Directory format:
	-- Offset  Bytes  Description
	-- 0       4      End of central directory signature
	-- 4       2      Number of this disk
	-- 6       2      Disk where central directory starts
	-- 8       2      Number of central directory records on this disk
	-- 10      2      Total number of central directory records
	-- 12      4      Size of central directory (bytes)
	-- 16      4      Offset of start of central directory
	-- 20      2      Comment length (n)
	-- 22      n      Comment

	local cdEntries = buffer.readu16(self.data, pos + 10)
	local cdSize = buffer.readu32(self.data, pos + 12)
	local cdOffset = buffer.readu32(self.data, pos + 16)

	-- Validate CD boundaries and entry count
	local bufSize = buffer.len(self.data)
	if cdOffset >= bufSize or cdOffset + cdSize > bufSize then
		error("Invalid Central Directory offset or size")
	end

	-- Validate CD size range; min = 46 bytes per entry, max = 0xFFFF * 3 + 46 bytes per entry
	if cdSize < cdEntries * 46 or cdEntries * (0xFFFF * 3 + 46) < cdSize then
		error("Invalid Central Directory size for claimed number of entries")
	end

	local commentLength = buffer.readu16(self.data, pos + 20)
	return {
		diskNumber = buffer.readu16(self.data, pos + 4),
		diskWithCD = buffer.readu16(self.data, pos + 6),
		cdEntries = cdEntries,
		totalCDEntries = buffer.readu16(self.data, pos + 8),
		cdSize = cdSize,
		cdOffset = cdOffset,
		comment = buffer.readstring(self.data, pos + 22, commentLength),
	}
end

--[=[
	@within ZipReader
	@method parseCentralDirectory
	@private

	Parses the central directory of the ZIP file and populates the `entries` and `directories` 
	fields. Used internally during initialization of the [ZipReader].

	**Errors if the ZIP file is invalid.**
	
	@error "Invalid Central Directory entry signature"
	@error "Found different entries than specified in Central Directory"
]=]
function ZipReader.parseCentralDirectory(self: ZipReader): ()
	local eocdPos = self:findEocdPosition()
	local record = self:parseEocdRecord(eocdPos)

	-- Track actual entries found
	local entriesFound = 0
	local pos = record.cdOffset
	while pos < record.cdOffset + record.cdSize do
		if buffer.readu32(self.data, pos) ~= SIGNATURES.CENTRAL_DIR then
			error("Invalid Central Directory entry signature")
		end

		-- Central Directory Entry format:
		-- Offset  Bytes  Description
		-- 0       4      Central directory entry signature
		-- 4       2      Version made by
		-- 8       2      General purpose bitflags
		-- 10      2      Compression method (8 = DEFLATE)
		-- 12      4      Last mod time/date
		-- 16      4      CRC-32
		-- 20      4      Compressed size
		-- 24      4      Uncompressed size
		-- 28      2      File name length (n)
		-- 30      2      Extra field length (m)
		-- 32      2      Comment length (k)
		-- 36      2      Internal file attributes
		-- 38      4      External file attributes
		-- 42      4      Local header offset
		-- 46      n      File name
		-- 46+n    m      Extra field
		-- 46+n+m  k      Comment

		local versionMadeBy = buffer.readu16(self.data, pos + 4)
		local _bitflags = buffer.readu16(self.data, pos + 8)
		local timestamp = buffer.readu32(self.data, pos + 12)
		local compressionMethod = buffer.readu16(self.data, pos + 10)
		local crc = buffer.readu32(self.data, pos + 16)
		local compressedSize = buffer.readu32(self.data, pos + 20)
		local size = buffer.readu32(self.data, pos + 24)
		local nameLength = buffer.readu16(self.data, pos + 28)
		local extraLength = buffer.readu16(self.data, pos + 30)
		local commentLength = buffer.readu16(self.data, pos + 32)
		local internalAttrs = buffer.readu16(self.data, pos + 36)
		local externalAttrs = buffer.readu32(self.data, pos + 38)
		local offset = buffer.readu32(self.data, pos + 42)
		local name = buffer.readstring(self.data, pos + 46, nameLength)

		local entrySize = 46 + nameLength + extraLength + commentLength
		if pos + entrySize > record.cdOffset + record.cdSize then
			error("Invalid Central Directory entry size")
		end

		table.insert(
			self.entries,
			ZipEntry.new(offset, name, {
				versionMadeBy = versionMadeBy,
				compressedSize = compressedSize,
				size = size,
				crc = crc,
				method = DECOMPRESSION_ROUTINES[compressionMethod].name :: CompressionMethod,
				timestamp = timestamp,
				attributes = externalAttrs,
				isText = bit32.btest(internalAttrs, 0x0001),
			})
		)

		pos = pos + 46 + nameLength + extraLength + commentLength
		entriesFound += 1
	end

	if entriesFound ~= record.cdEntries then
		error("Found different entries than specified in Central Directory")
	end

	self.comment = record.comment
end

--[=[
	@within ZipReader
	@method buildDirectoryTree
	@private

	Builds the directory tree from the entries. Used internally during initialization of the 
	[ZipReader].
]=]
function ZipReader.buildDirectoryTree(self: ZipReader): ()
	-- Sort entries to process directories first; I could either handle
	-- directories and files in separate passes over the entries, or sort
	-- the entries so I handled the directories first -- I decided to do
	-- the latter
	table.sort(self.entries, function(a, b)
		if a.isDirectory ~= b.isDirectory then
			return a.isDirectory
		end
		return a.name < b.name
	end)

	for _, entry in self.entries do
		local parts = {}
		-- Split entry path into individual components
		-- e.g. "folder/subfolder/file.txt" -> {"folder", "subfolder", "file.txt"}
		for part in string.gmatch(entry.name, "([^/]+)/?") do
			table.insert(parts, part)
		end

		-- Start from root directory
		local current = self.root
		local path = ""

		-- Process each path component
		for i, part in parts do
			path ..= part

			if i < #parts or entry.isDirectory then
				-- Create missing directory entries for intermediate paths
				if not self.directories[path] then
					if entry.isDirectory and i == #parts then
						-- Existing directory entry, reuse it
						self.directories[path] = entry
					else
						-- Create new directory entry for intermediate paths or undefined
						-- parent directories in the ZIP
						local dir = ZipEntry.new(0, path .. "/", {
							versionMadeBy = 0,
							compressedSize = 0,
							size = 0,
							crc = 0,
							compressionMethod = "STORED",
							timestamp = entry.timestamp,
							attributes = entry.attributes,
						})

						dir.versionMadeBy = entry.versionMadeBy
						dir.isDirectory = true
						dir.parent = current
						self.directories[path] = dir
					end

					-- Track directory in both lookup table and parent's children
					table.insert(current.children, self.directories[path])
				end

				-- Move deeper into the tree
				current = self.directories[path]
				continue
			end

			-- Link file entry to its parent directory
			entry.parent = current
			table.insert(current.children, entry)
		end
	end
end

--[=[
	@within ZipReader
	@method findEntry
	
	Finds a [ZipEntry] by its path in the ZIP archive.

	@param path string -- Path to the entry to find
	@return ZipEntry? -- The found entry, or `nil` if not found
]=]
function ZipReader.findEntry(self: ZipReader, path: string): ZipEntry?
	if path == "/" then
		-- If the root directory's entry was requested we do not
		-- need to do any additional work
		return self.root
	end

	-- Normalize path by removing leading and trailing slashes
	-- This ensures consistent lookup regardless of input format
	-- e.g., "/folder/file.txt/" -> "folder/file.txt"
	path = string.gsub(path, "^/", ""):gsub("/$", "")

	-- First check regular files and explicit directories
	for _, entry in self.entries do
		-- Compare normalized paths
		if string.gsub(entry.name, "/$", "") == path then
			return entry
		end
	end

	-- If not found, check virtual directory entries
	-- These are directories that were created implicitly
	return self.directories[path]
end

--[=[
	@interface ExtractionOptions
	@within ZipReader
	@ignore

	Options accepted by the [ZipReader:extract] method.

	@field followSymlinks boolean? -- Whether to follow symlinks
	@field decompress boolean -- Whether to decompress the entry or only return the raw data
	@field type ("binary" | "text")? -- The type of data to return, automatically inferred based on the type of contents if not specified
	@field skipCrcValidation boolean? -- Whether to skip CRC validation
	@field skipSizeValidation boolean? -- Whether to skip size validation
]=]
type ExtractionOptions = {
	followSymlinks: boolean?,
	decompress: boolean?,
	type: ("binary" | "text")?,
	skipCrcValidation: boolean?,
	skipSizeValidation: boolean?,
}

--[=[
	@within ZipReader
	@method extract

	Extracts the specified [ZipEntry] from the ZIP archive. See [ZipReader:extractDirectory] for 
	extracting directories.

	@error "Cannot extract directory" -- If the entry is a directory, use [ZipReader:extractDirectory] instead
	@error "Invalid local file header" -- Invalid ZIP file, local header signature did not match
	@error "Unsupported PKZip spec version: {versionNeeded}" -- The ZIP file was created with an unsupported version of the ZIP specification
	@error "Symlink path not found" -- If `followSymlinks` of options is `true` and the symlink path was not found
	@error "Unsupported compression, ID: {compressionMethod}" -- The entry was compressed using an unsupported compression method

	@param entry ZipEntry -- The entry to extract
	@param options ExtractionOptions? -- Options for the extraction
	@return buffer | string -- The extracted data
]=]
function ZipReader.extract(self: ZipReader, entry: ZipEntry, options: ExtractionOptions?): buffer | string
	-- Local File Header format:
	-- Offset  Bytes  Description
	-- 0       4      Local file header signature
	-- 4       2      Version needed to extract
	-- 6       2      General purpose bitflags
	-- 8       2      Compression method (8 = DEFLATE)
	-- 14      4      CRC32 checksum
	-- 18      4      Compressed size
	-- 22      4      Uncompressed size
	-- 26      2      File name length (n)
	-- 28      2      Extra field length (m)
	-- 30      n      File name
	-- 30+n    m      Extra field
	-- 30+n+m  -      File data

	if entry.isDirectory then
		error("Cannot extract directory")
	end

	local defaultOptions: ExtractionOptions = {
		followSymlinks = false,
		decompress = true,
		type = if entry.isText then "text" else "binary",
		skipValidation = false,
	}

	-- TODO: Use a `Partial` type function for this in the future!
	local optionsOrDefault: {
		followSymlinks: boolean,
		decompress: boolean,
		type: "binary" | "text",
		skipCrcValidation: boolean,
		skipSizeValidation: boolean,
	} = if options
		then setmetatable(options, { __index = defaultOptions }) :: any
		else defaultOptions

	local pos = entry.offset
	if buffer.readu32(self.data, pos) ~= SIGNATURES.LOCAL_FILE then
		error("Invalid local file header")
	end

	-- Validate that the version needed to extract is supported
	local versionNeeded = buffer.readu16(self.data, pos + 4)
	assert(MAX_SUPPORTED_PKZIP_VERSION >= versionNeeded, `Unsupported PKZip spec version: {versionNeeded}`)

	local bitflags = buffer.readu16(self.data, pos + 6)
	local crcChecksum = buffer.readu32(self.data, pos + 14)
	local compressedSize = buffer.readu32(self.data, pos + 18)
	local uncompressedSize = buffer.readu32(self.data, pos + 22)
	local nameLength = buffer.readu16(self.data, pos + 26)
	local extraLength = buffer.readu16(self.data, pos + 28)

	pos = pos + 30 + nameLength + extraLength

	if bit32.btest(bitflags, 0x08) then
		-- The bit at offset 3 was set, meaning we did not have the file sizes
		-- and CRC checksum at the time of the creation of the ZIP. Instead, they
		-- were appended after the compressed data chunks in a data descriptor

		-- Data Descriptor format:
		-- Offset   Bytes   Description
		-- 0        0 or 4  0x08074b50 (optional signature)
		-- 0 or 4   4       CRC32 checksum
		-- 4 or 8   4       Compressed size
		-- 8 or 12  4       Uncompressed size

		-- Start at the compressed data
		local descriptorPos = pos
		while true do
			-- Try reading a u32 starting from current offset
			local leading = buffer.readu32(self.data, descriptorPos)

			if leading == SIGNATURES.DATA_DESCRIPTOR then
				-- If we find a data descriptor signature, that must mean
				-- the current offset points to the start of the descriptor
				break
			end

			if leading == entry.crc then
				-- If we find our file's CRC checksum, that means the data
				-- descriptor signature was omitted, so our chunk starts 4
				-- bytes before
				descriptorPos -= 4
				break
			end

			-- Skip to the next byte
			descriptorPos += 1
		end

		crcChecksum = buffer.readu32(self.data, descriptorPos + 4)
		compressedSize = buffer.readu32(self.data, descriptorPos + 8)
		uncompressedSize = buffer.readu32(self.data, descriptorPos + 12)
	end

	local content = buffer.create(compressedSize)
	buffer.copy(content, 0, self.data, pos, compressedSize)

	if optionsOrDefault.decompress then
		local compressionMethod = buffer.readu16(self.data, entry.offset + 8)
		local algo = DECOMPRESSION_ROUTINES[compressionMethod]
		if algo == nil then
			error(`Unsupported compression, ID: {compressionMethod}`)
		end

		if optionsOrDefault.followSymlinks then
			local linkPath = buffer.tostring(algo.decompress(content, 0, {
				expected = 0x00000000,
				skip = true,
			}))

			-- Check if the path was a relative path
			if path.isRelative(linkPath) then
				if string.sub(linkPath, -1) ~= "/" then
					linkPath ..= "/"
				end

				linkPath = path.canonicalize(`{(entry.parent or self.root).name}{linkPath}`)
			end

			optionsOrDefault.followSymlinks = false
			optionsOrDefault.type = "binary"
			optionsOrDefault.skipCrcValidation = true
			optionsOrDefault.skipSizeValidation = true
			content =
				self:extract(self:findEntry(linkPath) or error("Symlink path not found"), optionsOrDefault) :: buffer
		end

		content = algo.decompress(content, uncompressedSize, {
			expected = crcChecksum,
			skip = optionsOrDefault.skipCrcValidation,
		})

		-- Unless skipping validation is requested, we make sure the uncompressed size matches
		assert(
			optionsOrDefault.skipSizeValidation or uncompressedSize == buffer.len(content),
			"Validation failed; uncompressed size does not match"
		)
	end

	return if optionsOrDefault.type == "text" then buffer.tostring(content) else content
end

--[=[
	@within ZipReader
	@method extractDirectory

	Extracts all the files in a specified directory, skipping any directory entries.

	**Errors if [ZipReader:extract] errors on an entry in the directory.**

	@param path string -- The path to the directory to extract
	@param options ExtractionOptions? -- Options for the extraction
	@return { [string]: buffer } | { [string]: string } -- A map of extracted file paths and their contents
]=]
function ZipReader.extractDirectory(
	self: ZipReader,
	path: string,
	options: ExtractionOptions?
): { [string]: buffer } | { [string]: string }
	local files: { [string]: buffer } | { [string]: string } = {}
	-- Normalize path by removing leading slash for consistent prefix matching
	path = string.gsub(path, "^/", "")

	-- Iterate through all entries to find files within target directory
	for _, entry in self.entries do
		-- Check if entry is a file (not directory) and its path starts with target directory
		if not entry.isDirectory and string.sub(entry.name, 1, #path) == path then
			-- Store extracted content mapped to full path
			files[entry.name] = self:extract(entry, options)
		end
	end

	-- Return a map of file to contents
	return files
end

--[=[
	@within ZipReader
	@method listDirectory

	Lists the entries within a specified directory path.

	@error "Not a directory" -- If the path does not exist or is not a directory

	@param path string -- The path to the directory to list
	@return { ZipEntry } -- The list of entries in the directory
]=]
function ZipReader.listDirectory(self: ZipReader, path: string): { ZipEntry }
	-- Locate the entry with the path
	local entry = self:findEntry(path)
	if not entry or not entry.isDirectory then
		-- If an entry was not found, we error
		error("Not a directory")
	end

	-- Return the children of our discovered entry
	return entry.children
end

--[=[
	@within ZipReader
	@method walk

	Recursively walks through the ZIP file, calling the provided callback for each entry
	with the current entry and its depth.

	@param callback (entry: ZipEntry, depth: number) -> () -- The function to call for each entry
]=]
function ZipReader.walk(self: ZipReader, callback: (entry: ZipEntry, depth: number) -> ()): ()
	-- Wrapper function which recursively calls callback for every child
	-- in an entry
	local function walkEntry(entry: ZipEntry, depth: number)
		callback(entry, depth)

		for _, child in entry.children do
			-- ooo spooky recursion... blame this if shit go wrong
			walkEntry(child, depth + 1)
		end
	end

	walkEntry(self.root, 0)
end

--[=[
	@interface ZipStatistics
	@within ZipReader

	@field fileCount number -- The number of files in the ZIP 
	@field dirCount number -- The number of directories in the ZIP 
	@field totalSize number -- The total size of all files in the ZIP 
]=]
export type ZipStatistics = { fileCount: number, dirCount: number, totalSize: number }

--[=[
	@within ZipReader
	@method getStats

	Retrieves statistics about the ZIP file.

	@return ZipStatistics -- The statistics about the ZIP file
]=]
function ZipReader.getStats(self: ZipReader): ZipStatistics
	local stats: ZipStatistics = {
		fileCount = 0,
		dirCount = 0,
		totalSize = 0,
	}

	-- Iterate through the entries, updating stats
	for _, entry in self.entries do
		if entry.isDirectory then
			stats.dirCount += 1
			continue
		end

		stats.fileCount += 1
		stats.totalSize += entry.size
	end

	return stats
end

return {
	-- Creates a `ZipReader` from a `buffer` of ZIP data.
	load = function(data: buffer)
		return ZipReader.new(data)
	end,
}
