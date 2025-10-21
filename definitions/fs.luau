local pathtype = require("@std/path/types")

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

function fs.open(path: pathtype.pathlike, mode: HandleMode?): FileHandle
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

function fs.remove(path: pathtype.pathlike): ()
	error("not implemented")
end

function fs.stat(path: pathtype.pathlike): FileMetadata
	error("not implemented")
end

function fs.type(path: pathtype.pathlike): FileType
	error("not implemented")
end

function fs.mkdir(path: pathtype.pathlike): ()
	error("not implemented")
end

function fs.link(src: pathtype.pathlike, dest: pathtype.pathlike): ()
	error("not implemented")
end

function fs.symlink(src: pathtype.pathlike, dest: pathtype.pathlike): ()
	error("not implemented")
end

function fs.watch(
	path: pathtype.pathlike,
	callback: (filename: pathtype.pathlike, event: WatchEvent) -> ()
): WatchHandle
	error("not implemented")
end

function fs.exists(path: pathtype.pathlike): boolean
	error("not implemented")
end

function fs.copy(src: pathtype.pathlike, dest: pathtype.pathlike): ()
	error("not implemented")
end

function fs.listdir(path: pathtype.pathlike): { DirectoryEntry }
	error("not implemented")
end

function fs.rmdir(path: pathtype.pathlike): ()
	error("not implemented")
end

function fs.readfiletostring(filepath: pathtype.pathlike): string
	error("not implemented")
end

function fs.writestringtofile(filepath: pathtype.pathlike, contents: string): ()
	error("not implemented")
end

function fs.readasync(filepath: pathtype.pathlike): string
	error("not implemented")
end

return fs
