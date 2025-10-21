local path = require("@std/path")

local fs = {}

export type FileHandle = {
	fd: number,
	err: number,
}

export type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"
export type HandleMode = "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+"

export type FileMetadata = {
	type: FileType,
	permissions: { readonly: boolean },
	size: number,
	created: any,
	accessed: any,
	modified: any,
}

export type DirectoryEntry = {
	name: string,
	type: FileType,
}

export type WatchHandle = {
	close: (self: WatchHandle) -> (),
}

export type WatchEvent = {
	change: boolean,
	rename: boolean,
}

function fs.open(path: path.pathlike, mode: HandleMode?): FileHandle
	error("not implemented")
end

function fs.read(handle: FileHandle): string
	error("not implemented")
end

function fs.write(handle: FileHandle, contents: string): ()
	error("not implemented")
end

function fs.close(handle: FileHandle): ()
	error("not implemented")
end

function fs.remove(path: path.pathlike): ()
	error("not implemented")
end

function fs.stat(path: path.pathlike): FileMetadata
	error("not implemented")
end

function fs.type(path: path.pathlike): FileType
	error("not implemented")
end

function fs.mkdir(path: path.pathlike): ()
	error("not implemented")
end

function fs.link(src: path.pathlike, dest: path.pathlike): ()
	error("not implemented")
end

function fs.symlink(src: path.pathlike, dest: path.pathlike): ()
	error("not implemented")
end

function fs.watch(
	path: path.pathlike,
	callback: (filename: path.pathlike, event: WatchEvent) -> ()
): WatchHandle
	error("not implemented")
end

function fs.exists(path: path.pathlike): boolean
	error("not implemented")
end

function fs.copy(src: path.pathlike, dest: path.pathlike): ()
	error("not implemented")
end

function fs.listdir(path: path.pathlike): { DirectoryEntry }
	error("not implemented")
end

function fs.rmdir(path: path.pathlike): ()
	error("not implemented")
end

function fs.readfiletostring(filepath: path.pathlike): string
	error("not implemented")
end

function fs.writestringtofile(filepath: path.pathlike, contents: string): ()
	error("not implemented")
end

function fs.readasync(filepath: path.pathlike): string
	error("not implemented")
end

return fs
