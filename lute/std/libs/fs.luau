--!strict
-- @std/fs
-- stdlib for `@lute/fs`
-- Provides file system utility functions that handles file paths as path types instead of strings

local deque = require("@batteries/collections/deque")
local fs = require("@lute/fs")
local pathlib = require("@std/path")
local sys = require("@std/system")
local win32paths = require("@std/path/win32")

local fslib = {}

--- How a file should be opened:
--- - `"r"`: Open for reading. Fails if the file does not exist.
--- - `"w"`: Open for writing; creates the file if absent, truncates it if present.
--- - `"x"`: Open for exclusive creation. Fails if the file already exists.
--- - `"a"`: Open for appending; creates the file if absent, writes go to the end.
--- - `"r+"`: Open for reading and writing. Fails if the file does not exist.
--- - `"w+"`: Open for reading and writing; creates the file if absent, truncates it if present.
--- - `"x+"`: Open for reading and exclusive creation. Fails if the file already exists.
--- - `"a+"`: Open for reading and appending; creates the file if absent, writes go to the end.
export type HandleMode = fs.HandleMode
--- An open file handle.
export type File = fs.FileHandle
--- The type of a filesystem entry:
--- - `"file"`: A regular file.
--- - `"dir"`: A directory.
--- - `"link"`: A symbolic link.
--- - `"fifo"`: A named pipe (FIFO).
--- - `"socket"`: A Unix domain socket.
--- - `"char"`: A character device.
--- - `"block"`: A block device.
--- - `"unknown"`: An entry whose type could not be determined.
export type FileType = fs.FileType
--- Metadata about a filesystem entry, such as size, type, and timestamps.
export type FileMetadata = fs.FileMetadata
--- A single entry returned by `listDirectory`, containing the entry's name and type.
export type DirectoryEntry = fs.DirectoryEntry
--- A handle to an active filesystem watcher, returned by `watch`.
export type WatchHandle = fs.WatchHandle
--- A filesystem change event, yielded by a `Watcher`.
export type WatchEvent = fs.WatchEvent

type Pathlike = pathlib.Pathlike
type Path = pathlib.Path
type win32path = win32paths.Path

--- Options for `createDirectory`:
--- - `makeParents`: If `true`, creates any missing parent directories. Defaults to `false`.
export type CreateDirectoryOptions = {
	makeParents: boolean?,
}

--- Options for `removeDirectory`:
--- - `recursive`: If `true`, removes all contents of the directory before deleting it. Defaults to `false`.
export type RemoveDirectoryOptions = {
	recursive: boolean?,
}

--- Options for `walk`:
--- - `recursive`: If `true`, descends into subdirectories. Defaults to `false`.
export type WalkOptions = {
	recursive: boolean?,
}

type Watcher = {
	next: (Watcher) -> WatchEvent?,
	close: (self: Watcher) -> (),
}

--- Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle.
function fslib.open(path: Pathlike, mode: HandleMode?): File
	return fs.open(pathlib.format(path), mode)
end

--- Reads the full contents of `file` and returns them as a string.
function fslib.read(file: File): string
	return fs.read(file)
end

--- Writes `contents` to `file`.
function fslib.write(file: File, contents: string): ()
	return fs.write(file, contents)
end

--- Closes `file`, flushing any pending writes.
function fslib.close(file: File): ()
	return fs.close(file)
end

--- Removes the file at `path`.
function fslib.remove(path: Pathlike): ()
	return fs.remove(pathlib.format(path))
end

--- Returns metadata for the file or directory at `path`.
function fslib.metadata(path: Pathlike): FileMetadata
	return fs.stat(pathlib.format(path))
end

--- Returns the `FileType` of the entry at `path` (e.g. `"file"`, `"dir"`, `"symlink"`).
function fslib.type(path: Pathlike): FileType
	return fs.type(pathlib.format(path))
end

--- Creates a hard link at `dest` pointing to `src`.
function fslib.link(src: Pathlike, dest: Pathlike): ()
	return fs.link(pathlib.format(src), pathlib.format(dest))
end

--- Creates a symbolic link at `dest` pointing to `src`.
function fslib.symbolicLink(src: Pathlike, dest: Pathlike): ()
	return fs.symlink(pathlib.format(src), pathlib.format(dest))
end

--- Watches `path` for filesystem changes. Returns a `Watcher` with a `next` method that returns the next
--- `WatchEvent`, or `nil` if none is available, and a `close` method to stop watching.
--- Note: a while loop must be used rather than a for loop. See example/watch_directory.luau for usage.
function fslib.watch(path: Pathlike): Watcher
	-- In the future this could be written with explicit instantiation syntax
	-- as in:
	--
	--	deque.new<<{ filename: path, event: watchevent }>>()
	local deq = deque.new(nil :: { filename: Path, event: WatchEvent }?)
	local handle = fs.watch(pathlib.format(path), function(filename, event)
		deq:pushback({ filename = pathlib.parse(filename), event = event })
	end)

	return {
		next = function(_self: Watcher): WatchEvent?
			if not deq:peekfront() then
				return nil
			end
			local item = deq:popfront()
			assert(item)
			return item.event
		end,
		close = function(_self: Watcher): ()
			if handle then
				handle:close()
			end
		end,
	}
end

--- Returns `true` if a file or directory exists at `path`.
function fslib.exists(path: Pathlike): boolean
	return fs.exists(pathlib.format(path))
end

--- Copies the file at `src` to `dest`.
function fslib.copy(src: Pathlike, dest: Pathlike): ()
	return fs.copy(pathlib.format(src), pathlib.format(dest))
end

--- Moves the file or directory at `src` to `dest`.
--- Falls back to a copy-then-remove if `src` and `dest` are on different filesystems.
function fslib.move(src: Pathlike, dest: Pathlike): ()
	return fs.move(pathlib.format(src), pathlib.format(dest))
end

--- Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`.
function fslib.listDirectory(path: Pathlike): { DirectoryEntry }
	return fs.listdir(pathlib.format(path))
end

--- Returns the entire contents of the file at `filepath` as a string.
function fslib.readFileToString(filepath: Pathlike): string
	local f = fs.open(pathlib.format(filepath), "r")
	local contents = fs.read(f)
	fs.close(f)
	return contents
end

--- Writes `contents` to the file at `filepath`, replacing any existing contents.
function fslib.writeStringToFile(filepath: Pathlike, contents: string): ()
	local f = fs.open(pathlib.format(filepath), "w+")
	fs.write(f, contents)
	fs.close(f)
end

--- Creates a directory at `path`. If `options.makeParents` is `true`, creates any missing parent directories as well.
function fslib.createDirectory(path: Pathlike, options: CreateDirectoryOptions?): ()
	if options and options.makeParents then
		local parsed = pathlib.parse(path)
		local parts: { string } = parsed.parts

		local subdir: Pathlike = "."
		if pathlib.isAbsolute(path) then
			if sys.win32 then
				-- Windows path - get the drive root like "C:\"
				subdir = pathlib.win32.drive(parsed :: win32path)
			else
				-- POSIX absolute path - start from root "/"
				subdir = pathlib.format({ absolute = true, parts = {} })
			end
		end

		for _, part in parts do
			subdir = pathlib.join(subdir, part)
			if not fslib.exists(subdir) then
				fs.mkdir(pathlib.format(subdir))
			end
		end
	else
		fs.mkdir(pathlib.format(path))
	end
end

--- Removes the directory at `path`. If `options.recursive` is `true`, removes all contents first.
function fslib.removeDirectory(path: Pathlike, options: RemoveDirectoryOptions?): ()
	if options and options.recursive then
		-- Recursively delete all contents first
		if fslib.exists(path) and fslib.type(path) == "dir" then
			local entries = fslib.listDirectory(path)
			for _, entry in entries do
				local entryPath = pathlib.join(path, entry.name)
				if entry.type == "dir" then
					fslib.removeDirectory(entryPath, { recursive = true })
				else
					fslib.remove(entryPath)
				end
			end
			fs.rmdir(pathlib.format(path))
		end
	else
		fs.rmdir(pathlib.format(path))
	end
end

--- Returns an iterator over all paths under `path`. If `options.recursive` is `true`, descends into subdirectories.
--- See example/walk_directory.luau for usage.
function fslib.walk(path: Pathlike, options: WalkOptions?): () -> Path?
	local queue = deque.new(pathlib.parse(path))
	local recursive = if options then options.recursive else false

	return function()
		if #queue == 0 then
			return nil
		end

		local current = queue:popfront()

		if fslib.type(current) == "dir" and recursive then
			local entries = fslib.listDirectory(current)
			for _, entry in entries do
				queue:pushback(pathlib.join(current, entry.name))
			end
		end

		return current
	end
end

return table.freeze(fslib)
