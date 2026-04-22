-- lute-lint-global-ignore(unused_variable)
local time = require("./time")

local fs = {}

--- An open file handle returned by `fs.open`.
export type FileHandle = {
	fd: number,
	err: number,
}

--- The type of a filesystem entry:
--- - `"file"`: A regular file.
--- - `"dir"`: A directory.
--- - `"link"`: A symbolic link.
--- - `"fifo"`: A named pipe (FIFO).
--- - `"socket"`: A Unix domain socket.
--- - `"char"`: A character device.
--- - `"block"`: A block device.
--- - `"unknown"`: An entry whose type could not be determined.
export type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"
--- How a file should be opened:
--- - `"r"`: Open for reading. Fails if the file does not exist.
--- - `"w"`: Open for writing; creates the file if absent, truncates it if present.
--- - `"x"`: Open for exclusive creation. Fails if the file already exists.
--- - `"a"`: Open for appending; creates the file if absent, writes go to the end.
--- - `"r+"`: Open for reading and writing. Fails if the file does not exist.
--- - `"w+"`: Open for reading and writing; creates the file if absent, truncates it if present.
--- - `"x+"`: Open for reading and exclusive creation. Fails if the file already exists.
--- - `"a+"`: Open for reading and appending; creates the file if absent, writes go to the end.
export type HandleMode = "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+"

--- Metadata about a filesystem entry, such as size, type, and timestamps.
export type FileMetadata = {
	type: FileType,
	permissions: { readonly: boolean },
	size: number,
	created: time.Duration,
	accessed: time.Duration,
	modified: time.Duration,
}

--- A single entry returned by `fs.listdir`, containing the entry's name and type.
export type DirectoryEntry = {
	name: string,
	type: FileType,
}

--- A handle to an active filesystem watcher, returned by `fs.watch`.
export type WatchHandle = {
	close: (self: WatchHandle) -> (),
}

--- A filesystem change event passed to the `fs.watch` callback.
export type WatchEvent = {
	change: boolean,
	rename: boolean,
}

--- Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle.
function fs.open(path: string, mode: HandleMode?): FileHandle
	error("not implemented")
end

--- Reads the full contents of `handle` and returns them as a string.
function fs.read(handle: FileHandle): string
	error("not implemented")
end

--- Writes `contents` to `handle`.
function fs.write(handle: FileHandle, contents: string): ()
	error("not implemented")
end

--- Closes `handle`, flushing any pending writes.
function fs.close(handle: FileHandle): ()
	error("not implemented")
end

--- Removes the file at `path`.
function fs.remove(path: string): ()
	error("not implemented")
end

--- Returns metadata for the file or directory at `path`.
function fs.stat(path: string): FileMetadata
	error("not implemented")
end

--- Returns the `FileType` of the entry at `path`.
function fs.type(path: string): FileType
	error("not implemented")
end

--- Creates a directory at the specified path.
--- To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.
function fs.mkdir(path: string): ()
	error("not implemented")
end

--- Creates a hard link at `dest` pointing to `src`.
function fs.link(src: string, dest: string): ()
	error("not implemented")
end

--- Creates a symbolic link at `dest` pointing to `src`.
function fs.symlink(src: string, dest: string): ()
	error("not implemented")
end

--- Watches `path` for filesystem changes, calling `callback` with the filename and event on each change.
function fs.watch(path: string, callback: (filename: string, event: WatchEvent) -> ()): WatchHandle
	error("not implemented")
end

--- Returns `true` if a file or directory exists at `path`.
function fs.exists(path: string): boolean
	error("not implemented")
end

--- Copies the file at `src` to `dest`.
function fs.copy(src: string, dest: string): ()
	error("not implemented")
end

--- Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`.
function fs.listdir(path: string): { DirectoryEntry }
	error("not implemented")
end

--- Removes the directory at `path`.
function fs.rmdir(path: string): ()
	error("not implemented")
end

return fs
